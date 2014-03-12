Just unzip with the folder in the zip in to you project dir.

Now if you want to use the scroll view or the table view with the fixes do this:

 
local widgetFix = require ("widgets.widget")

local scroll = widgetFix.newScrollView(options)

 

same for table view.

If you need any other widgets include the default corona ones like you always do:

local widget = require ("widget")

 

Included fixes:

- scroll view and table view will not jump back to starting position if scrolling in opposite direction before bounce back has completed (vertical and horizontal)

- eliminated occasional error when removing objects from scroll view

- exposed scrollView:updateScrollAreaSize() for making sure the scroll works correctly when moving objects inside the scroll view

- fixed some issues when using multiple scroll views or table views at the same time

- scroll view and table view now respect the vertical scrolling threshold

- fixed table view bug when deleting multiple rows

- fixed table view deleteRow bug that says table view is scrolling when it's not and doesn't allow deletion

- all scrollTo methods for scrollView and tableView return the transition handle so it can be canceled if needed