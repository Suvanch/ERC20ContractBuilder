import random
import fileinput
from pathlib import Path
import requests


from tkinter import W

def randCode():
    print("Using rand code will drastically increase the gas price but will bypass the...")
    fullPath = "autoSol\\inputs\\"
    newFileName = "autoSol\\junkCode.txt"
    with open(fullPath + 'function\\function1.txt','r') as firstfile, open(newFileName,'a') as secondfile:
        for line in firstfile:
             secondfile.write(line)
        firstfile.close
        secondfile.close
    with open(newFileName, 'r') as file :
        filedata = file.read()
    
    filedata = filedata.replace('<randWord>', randLine())
    
    loop = Path(fullPath + 'loops\\loop1.txt').read_text()
    filedata = filedata.replace('<loop>', loop)
    filedata = filedata.replace('<randWord>',randWord()+randWord())
    filedata = filedata.replace('<string>', randStrings())
    


    with open(newFileName, 'w') as file:
        file.write(filedata)
    

def randLine():
    randNum = random.randint(1, 10)
    str = ""
    for x in range(randNum):
        str += randWord()
    return str

def randString():
    randNum = random.randint(1, 10)
    strName =  randLine()
    str = "string " +strName + "= \""
    for x in range(randNum):
        str += randWord()+" "
    str += "\";\n"
    return str
    

def randStrings():
    randNum = random.randint(1, 10)
    str = ""
    for x in range(randNum):
        str += randString()
    return str
    
#def stringComp():


def randWord():
    word_url = "https://www.mit.edu/~ecprice/wordlist.100000"
    response = requests.get(word_url)
    WORDS = response.content.splitlines()
    return random.choice(WORDS).decode("utf-8") 

randCode()
#randCode()
#randCode()
#randCode()
#randCode()