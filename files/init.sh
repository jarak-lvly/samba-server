#!/bin/bash

set -e

appSetup () {
    # Set variables
    DOMAIN=${DOMAIN:-SAMDOM.LOCAL}
    DOMAINPASS=${DOMAINPASS:-youshouldsetapassword^123}
    JOIN=${JOIN:-false}
    JOINSITE=${JOINSITE:-NONE}
    INSECURELDAP=${INSECURELDAP:-false}
    HOSTIP=${HOSTIP:-NONE}
    RPCPORTS=${RPCPORTS:-"49152-49172"}
    
    LDOMAIN=${DOMAIN,,}
    UDOMAIN=${DOMAIN^^}
    URDOMAIN=${UDOMAIN%%.*}

    # Set host ip option
    if [[ "$HOSTIP" != "NONE" ]]; then
        HOSTIP_OPTION="--host-ip=$HOSTIP"
    else
        HOSTIP_OPTION=""
    fi

    # Set up krb5.conf
    mv /etc/krb5.conf /etc/krb5.conf.orig

    # Copy my krb5.conf (minimal) from existing ad joined linux server
    cp -f /files/krb5.conf /etc/.

    # Set up samba
    # If the finished file isn't there, this is brand new, we're not just moving to a new container
    FIRSTRUN=false

    # For some reason /var/lib/samba/private is not there so check first
    # If it is not there you might get an error e.g. : "Failed to open /var/lib/samba/private/secrets.tdb"
    if [[ ! -d /var/lib/samba/private ]]; then
        mkdir /var/lib/samba/private
    else
        echo "Directory /var/lib/private already exists"
    fi

    if [[ ! -f /etc/samba/external/smb.conf ]]; then
        FIRSTRUN=true

        mv /etc/samba/smb.conf /etc/samba/smb.conf.default
        # Use our pre_smb.conf file for domain winbind info
        cp -f /files/pre_smb.conf /etc/samba/smb.conf

        if [[ ${JOIN,,} == "true" ]]; then
            if [[ ${JOINSITE} == "NONE" ]]; then
                samba-tool domain join ${LDOMAIN} MEMBER -U"${URDOMAIN}\administrator" \
                    --password="${DOMAINPASS}" \
                    --dns-backend=SAMBA_INTERNAL
            else
                samba-tool domain join ${LDOMAIN} MEMBER -U"${URDOMAIN}\administrator" \
                    --password="${DOMAINPASS}" \
                    --dns-backend=SAMBA_INTERNAL \
                    --site=${JOINSITE}
            fi
        fi
        if [[ ${INSECURELDAP,,} == "true" ]]; then
            sed -i "/\[global\]/a \
                \\\tldap server require strong auth = no\
                " /etc/samba/smb.conf
        fi

        # Once we are set up, we'll make a file so that we know to use it if we ever spin this up again
        # Use our smb.conf file after joining domain
        cp -f /etc/samba/smb.conf /etc/samba/external/smb.conf.orig
        cp -f /files/smb.conf /etc/samba/smb.conf
        cp -f /etc/samba/smb.conf /etc/samba/external/smb.conf
    else
        cp -f /etc/samba/external/smb.conf /etc/samba/smb.conf
    fi

    # Set up winbind offline logon / pam_winbind cached login
    # Note the winbind options added during domain join
    if [[ ! -f /etc/security/pam_winbind.conf ]]; then
        cp /files/pam_winbind.conf /etc/security/pam_winbind.conf
    else
        cp /etc/security/pam_winbind.conf /etc/security/pam_winbind.conf.orig
        sed -i "s/^;cached_login = no/cached_login = yes/" /etc/security/pam_winbind.conf
        sed -i "s/^;krb5_ccache_type =.*/krb5_ccache_type = FILE/" /etc/security/pam_winbind.conf
    fi

    # Create dir for socket
    if [[ ! -d /var/run/supervisor ]] ; then
        mkdir /var/run/supervisor
    else
        echo "Directory /var/run/supervisor already exists"
    fi

    if [[ ! -f /etc/supervisor/supervisord.conf.orig ]] ; then
        cp -p /etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf.orig
        sed -i '/^\[supervisord\]$/a nodaemon=true' /etc/supervisor/supervisord.conf
        sed -i 's|/var/run|/var/run/supervisor|g' /etc/supervisor/supervisord.conf
    fi
    cp -f /files/samba_supervisord.conf /etc/supervisor/conf.d/samba_supervisord.conf

    # Set up ntp config
    echo "" >> /etc/ntpsec/ntp.conf
    echo "# Additional" >> /etc/ntpsec/ntp.conf
    echo "ntpsigndsocket  /usr/local/samba/var/lib/ntp_signd/" >> /etc/ntpsec/ntp.conf
    echo "restrict 172.29.48.0 mask 255.255.255.0 nomodify" >> /etc/ntpsec/ntp.conf
    sed -i 's/\bnopeer\b//g' /etc/ntpsec/ntp.conf

    # Temp fix for this bug
    if [[ ! -d /var/log/ntpsec ]] ; then
        mkdir /var/log/ntpsec
        chown ntpsec:ntpsec /var/log/ntpsec
    else
        echo "Directory /var/log/ntpsec already exists"
    fi

    appStart ${FIRSTRUN}
}

remapSID () {
    # map Windows staff SID to local group staff gid
    # to run this command smbd and winbindd need to running and then restarted after
    # midtown staff  rc is 0 or 255

    # Temp disable exit on error behavior
    set +e
    staff_sid="S-1-5-21-1171572596-2607848987-4075488645-1601"
    group_check=$(net groupmap list sid="$staff_sid" 2>&1)
    if [[ "$?" -ne 0 ]]; then
        echo "groupmap does not exist... adding"
        net groupmap add sid="$staff_sid" unixgroup=staff
    fi
    supervisorctl restart smbd winbindd
    # Re-enable exit on error behavior
    set -e
}

appStart () {
    /usr/bin/supervisord -c /etc/supervisor/supervisord.conf > /var/log/supervisor/supervisor.log 2>&1 &

    if [ "${1}" = "true" ]; then
        echo "Sleeping 10 before remapping unixgroup staff"
        sleep 15
        remapSID
    fi

    while [ ! -f /var/log/supervisor/supervisor.log ]; do
        echo "Waiting for log files..."
        sleep 1
    done
    sleep 3
    tail -F /var/log/supervisor/*.log
}

sleep 15
appSetup

exit 0

