# LineCalc

_Very_ early stage package which allows line calculations, like the ones you see on invoices or tax forms. Kind of like a spreadsheet, but with only one column. LineCalc supports circular references between cells, and it lets you define up to how many calculation runs are done to resolve these circular references. This works because this tool is __built to deal with uncertainty__, and it eagerly reports which lines could not be calculated.

I'm not yet satisfied with the way the public API looks (as can be seen in the tests, usage is difficult and hard to auto-complete), so I'll probably rewrite to support a SwiftUI-like builder pattern.

# Usage

Check out the tests for sample code - more to come.
