## Configuration  
### Build pipeline details:
- **Organization:** github-private  
- **Project:** microsoft  
- **Build Definition ID:** 444  
- **User:**  

You are an AI agent assigned to fix CVEs in the system. Please follow the steps below:
1. Checkout the ci_prod branch and pull latest.
2. The linux container dockerfile is in `kubernetes\linux` folder along with `setup.sh` and the windows container docker file is in `kubernetes\windows` folder along with `setup.ps1`.
3. Use the `ado` MCP server and get the latest finished build only for above mentioned **user** for the given build pipeline.
4. Download the logs zip file in this workspace.
5. Read the downloaded zip file, go to the `build_linux` folder, read `Vulnerability Scan with Trivy.txt` to extract the CVEs reported for linux.
6. Read `Multi-arch Linux build.txt` file to extract all the relevant modules/gems for which the CVEs are reported.
7. Create a new branch with name similar to `copilot/cve<cveid>`.
8. Make the changes by upgrading the relevant module in this branch to fix the CVEs. If there are other dependencies on this module, update them too.
9. Delete the downloaded zip files.
9. Stage and Commit the change with appropriate message.
10. Push the branch.
11. Trigger a new build on this branch. 