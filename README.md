Forked from https://github.com/Fmstrat/samba-domain  

# Samba Active Directory Domain Controller for Docker
  
A well documented, tried and tested Samba Active Directory Domain Controller that works with the standard Windows management tools; built from scratch using internal DNS and kerberos and not based on existing containers.
  
  
## Documentation

Latest documentation available at: [https://nowsci.com/samba-domain/](https://nowsci.com/samba-domain/)


## Additional Information

Yes, says "Domain Controller" but customized for our test environment:  JOINING as a MEMBER into an existing Windows AD Domain (functional level 2016).
This is acting as a samba server with ads/winbind running.  The uid/gids match all of the other boxes running samba.
For this subnet, there are Windows 11 nodes and one linux (app) server.  This set up was for proof of concept.   
  
Read the documentation at nowsci.com.  I've pretty much left things in the files/scripts as is.  I modified what I needed to for my env and commented out the bits I didn't use.

## Notes
  
### Test lab environment in Hyper-V 
Docker host = Rocky Linux 8.10  
Docker container = Ubuntu 24.04  
Samba Version = 4.19.5-Ubuntu  
Win AD DC = Windows Server 2022 Std  
Win AD client = Windows 11 Pro  
  
   
### Differences
On docker host:  
On the nowsci doc page, they show an example of creating an interface alias, but I had issues on my hyper-v test lab environment.  My workaround was to create a docker ipvlan network.  
  
Dockerfile and init scripts:  
I needed the latest samba build (ubuntu 24.04 had version 4.19.5).  
For testing logon caching -- I created a pam_winbind.conf file that copies over.  
I used a krb5.conf file that works in my environment.  It adds some key value pairs that the init script doesn't add, unless you run the ubuntu-join-domain.sh script, but that uses extra things that I don't need.  
AD Domain functional level is at 2016.  
  
  
Windows:   
Copy over my already in-use files, which I know works in the Win AD / winbind environment:  
krb5.conf  
pre_smb.conf # This is a minimal smb.conf that we use to join and then switch to the basic smb.conf  
smb.conf  # This smb.conf is basic; no fancy bells and whistles for this test.  
   

