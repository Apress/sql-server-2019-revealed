docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=Sql2017isfast" -p 1401:1433 --name sql2017 --hostname sql2017 -v c:\data:/var/opt/mssql -d mcr.microsoft.com/mssql/server:2017-CU14-ubuntu
