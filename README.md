## Features

A simple class with a getter for boxes that waits for the box to be openable, then closes the box as soon as the operation is done.
This should only be used in the case where you need to access Hive in a background Isolate.
Leave isMultiIsolate as false if you want to use this class everywhere for standardization purposes and it will behave the same as if it was a regular box.
