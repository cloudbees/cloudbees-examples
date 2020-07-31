# Jenkins Credentials Migration

Run the script in `export.groovy` in the Script Console on the source Jenkins. It will output an encoded message containing a flattened list of all system and folder credentials. 

Then, paste the value from that script as the value of the `encoded` variable from `import.groovy` and execute in the Script Console on the destination Jenkins. All the credentials and domains from the source Jenkins will now be imported to the system store of the destination Jenkins. 

These scripts were created by Ryan Carrigan and copped from is repo on May 8, 2020