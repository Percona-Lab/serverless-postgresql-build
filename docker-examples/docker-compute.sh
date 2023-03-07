docker run -d -t --name compute --entrypoint "/compute.sh" -p55432:55432 -e PAGESERVER=172.16.0.9 -e SAFEKEEPERS=172.16.0.9:5454 perconalab/neon:pg14-1.0.0
