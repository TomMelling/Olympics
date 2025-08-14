# Olympics Data Exploration

These SQL files were used to explore a Kaggle dataset (linked below) with records detailing every time an athlete competed in an event at the Summer and Winter Olympics. The data ranges from the 1896 Summer Olympics to the 2016 Summer Olympics. 

The file `Olympics EDA.sql` is used for exploratory data analysis, for example counting `NULL`s, investigating duplicates, and getting to know what the fields mean (this required a bit of external research too.) This EDA helped to inform me on how to answer some questions I found interesting, the queries for which are included in the other file `Olympics General Queries.sql`.

These questions include
* Which sports/ events were discontinued? (Jeu De Paume, Aeronautics, Art Competitions)
* What are the most regularly-competing countries that have *never* won a gold medal? (Philipines, Malaysia, Iceland - as of Rio 2016)
* What are the least regularly-competing countries that *have* won a gold medal? (Kosovo, Burundi, Suriname)
* Which athletes have appeared at the most Olympic games? (Ian Millar represented Canada in 10 Olympic games!)
* What ages were the youngest and oldest medal winners, and what sport did they compete in? (10 in Gymnastics, 73 in Art Competitions)

There are a lot of `NULL`s in the dataset, and this data seemed to not be missing at random. To investigate the missingness I created a variety of visualizations in Tableau. This was done in order for me to be more confident in my results and to avoid any observed trends being possibly influenced by missingness. The visualizations have since been corrupted and therefore can't be linked.

Data source: https://www.kaggle.com/datasets/heesoo37/120-years-of-olympic-history-athletes-and-results
