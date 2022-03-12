# REC20ContractBuilder #


This program automatically creates an ERC20 contract. You can currently edit the name, symbol, supply, tax, tax distribution, mintable, burnable, and options to add custom functions

I plan on adding random code, random comments, timelocks, and whitelists. I will also add other features as this starts to grow.



* To run program
  * Clone/Download repository
    * Top right under the green code button
    * Unzip everything
    * Open folder in VSCode
* Edit Your Contract
  * Open and edit the solMeta.json file
  * Random comments, Random code and Scam_fo_sho doesn't do anything yet
    * Leave them as false
* Generate/Deploy Contract
  * Once everything is ready run the autoSol.py file
    * This will create a new file in the same directory name <contractName>.sol
  * You can then copy the code and paste it into remix to deploy
* Rand Code Function
  * Rand code works but is really bad and slow. I might have to fix it or rebuild this part to make it more useable.
  * To see the current output of this 
    * run randCode.py file
      * This will create a new file called junkCode.txt.

I plan on automating the deployment process into the Dapp

_There are going to be lots of errors and bugs so if you find anything please let me know and I'll be sure to fix it. I have even tested all the edge cases so if you decide to not add something, type something odd or remove something the contract will come back with errors._
