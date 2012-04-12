module test;

import std.algorithm;
import std.array;
import std.stdio;
import pegged.grammar;

import pegged.examples.xml2;

import xmltest;

void main()
{
    //asModule("xmltest", XMLgrammar);
    writeln(XML.parse(`<?xml version="1.1" encoding="UTF-8" ?>
<!-- Edited by XMLSpy -->
<breakfast_menu>
<food>
<name>Belgian Waffles</name>
<price>$5.95</price>
<description>
two of our famous Belgian Waffles with plenty of real maple syrup
</description>
<calories>650</calories>
</food>
<food>
<name>Strawberry Belgian Waffles</name>
<price>$7.95</price>
<description>
light Belgian waffles covered with strawberries and whipped cream
</description>
<calories>900</calories>
</food>
<food>
<name>Berry-Berry Belgian Waffles</name>
<price>$8.95</price>
<description>
light Belgian waffles covered with an assortment of fresh berries and whipped cream
</description>
<calories>900</calories>
</food>
<food>
<name>French Toast</name>
<price>$4.50</price>
<description>
thick slices made from our homemade sourdough bread
</description>
<calories>600</calories>
</food>
<food>
<name>Homestyle Breakfast</name>
<price>$6.95</price>
<description>
two eggs, bacon or sausage, toast, and our ever-popular hash browns
</description>
<calories>950</calories>
</food>
</breakfast_menu>`));
}