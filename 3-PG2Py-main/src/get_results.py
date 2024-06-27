import sqlite3
import csv

# Create a SQL connection to our SQLite database
con = sqlite3.connect("../Output/Py3PG2Output.sqlite")

cur = con.cursor()


writer = csv.writer(open("../Output/Py3PG2Output.csv", 'w'))
# The result of a "cursor.execute" can be iterated over by row
for i in range(0, 1369):
	for row in cur.execute("select * from plot"+str(i)+" limit 1 offset 599;"):
		result = ((str(row).replace("(", "")).replace(")", "")).replace(",", ";")
		print(result)
		writer.writerow([str(i)+";"+result])

# Be sure to close the connection
con.close()
