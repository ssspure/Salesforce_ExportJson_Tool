### Salesforce_ExportJson_Tool

This tool is used for Salesforce data export and create json data files for sfdx import command.

It's mainly designed for solving the following two probles.

- The sfdx export command can only return a maximum of 1999 child records.

  ※parent 1 record + child 1999 record = 2000 records

- Although sfdx export command can create json file contain more than 200 records, but import json file can only contain up to  200 records.



### How to use it

I will use an example to illustrate how to use it.

Now, I want to export Account, Contact, Opportunity sObject data from scratch.  

In my scratch, I have the following data.

~~~sql
Select Count(Id) from Account     5373
Select Count(Id) from Contact     10190
Select count(Id) from Opportunity 7350
~~~



~~~sql
Select Account.Name, Count(Id) from Contact group by Account.Name
~~~

| Name                  | count(Id)   |
| --------------------- | ----------- |
| Dicta nihil iste iste | 3000        |
|                       | 1550        |
| Eos omnis ut assumend | 205         |
| Odit aut blanditiis e | 205         |
| Adipisci facere culpa | 100         |
| …..........           | ….......... |
| Accusamus voluptates  | 10          |
| Autem ipsa ex natus d | 10          |
| …..........           | ….......... |
| Accusantium ut quisqu | 1           |
| Ad eaque est iure ab  | 1           |
| …..........           | ….......... |



~~~sql
Select Account.Name, Count(Id) from Opportunity group by Account.Name
~~~

| Name                  | count(Id)   |
| --------------------- | ----------- |
|                       | 2100        |
| Dicta nihil iste iste | 600         |
| Laborum beatae neque  | 200         |
| Magni architecto exce | 200         |
| …..........           | ….......... |
| Asperiores magnam dol | 100         |
| …..........           | ….......... |
| Voluptate tenetur fac | 5           |
| …..........           | ….......... |
| Voluptatum eaque vel  | 1           |

Download the Salesforce_ExportJson_Tool and put the tool in Scratch Environment.

I use vs code, so I put the tool in vs code.

~~~
./scripts/
├── export_Account_Contact_Opportunity
│   ├── execute.bat
│   ├── execute.sh
│   └── soql.txt
└── exportJsonDataForImport
    └── execute.ps1
~~~



execute.ps1 is the main process of the tool.

execute.sh(Mac) and execute.bat(Windows) is the start shell of the execute.ps1.

※Install powershell when you use the tool in Mac.

※soql.txt must be in the same directory with execute.bat(or execute.sh)

Write soql in soql.txt.  

~~~sql
parentObjectSoql = Select Id, Name, BillingStreet, AccountNumber, Website, ShippingCountry, Phone, AccountSource from Account
childObjectSoql_1 = Select Id, LastName, FirstName, Email, Birthdate, LeadSource, Title, AccountId from Contact
childObjectSoql_2 = Select Id, Name, StageName, CloseDate, Amount, Probability, LeadSource, NextStep,AccountId from Opportunity
~~~

In soql.txt file,set parent soql to parentObjectSoql, set child soql to childObjectSoql_?.

**In child soql, you must contain the lookup relationship field**.(ex. AccountId field in Contact and AccountId field)



Beacuse I am using mac, so I execute the execute.sh file.

~~~bash
ssspure-2:bikeCard sunshuaishuai$ bash '/Users/sunshuaishuai/Coding/Salesforce/bikeCard/scripts/export_Account_Contact_Opportunity/execute.sh'
2021/04/11 19:30:37 | [INFO] You will create json data for Parent sObject: [Account], Child sObject:[Contact Opportunity].
2021/04/11 19:30:37 | [INFO] Start to Create Account sObject json files.
Querying Data... done
2021/04/11 19:31:04 | [INFO] Create Account sObject json files successfully.
2021/04/11 19:31:04 | [INFO] Start to Create Contact sObject json files.
Querying Data... done
2021/04/11 19:36:17 | [INFO] Create Contact sObject json files successfully.
2021/04/11 19:36:17 | [INFO] Start to Create Opportunity sObject json files.
Querying Data... done
2021/04/11 19:41:54 | [INFO] Create Opportunity sObject json files successfully.
2021/04/11 19:41:54 | [INFO] Create json files successfully.	
~~~

The tool will create data json file and plan json file in the same directory with soql.txt file.

~~~bash
./scripts/
├── apex
│   └── hello.apex
├── exportCodeData
│   ├── Account-Contact-Opportunity-plan.json
│   ├── Accounts1.json
│   ├── -----------------
│   ├── Accounts27.json
│   ├── Contacts1.json
│   ├── -----------------
│   ├── Contacts51.json
│   ├── Opportunitys1.json
│   ├── -----------------
│   ├── Opportunitys37.json
│   ├── execute.bat
│   ├── execute.sh
│   └── soql.txt
~~~

The tool create 200 records per data json file automatically.

Now you can use sfdx import cammand to import data with the json files.

~~~bash
sfdx force:data:tree:import -p ./scripts/export_Account_Contact_Opportunity/Account-Contact-Opportunity-plan.json
~~~

