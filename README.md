# Create Network

````
sudo docker network create -d bridge --subnet 192.168.0.0/24 --gateway 192.168.0.1 dockernet
````

# Start Containers

````
sudo docker-compose up
````

# Open browser

Browse to http://localhost:8080

# Close containers

````
sudo docker-compose down
````