Jamcrest C++ needs a tempalting mechanism that uses JavaScript input and support replacing variables supplied on the command line

jamcrest --template <template.req.js> --data <input.js> | curl ...


This will enable users to takea  request template and create a JSON output with global variables repalces with input variables

e.g template.req.js
```javascript
{
	user : {
		name: name,
		password: pass
	}
}
```

e.g input.js
```javascript
{
	name:"alice",
	pass: 1234
}
```

N.B. the input .js file alows using JavaScript primitive types, not just strings
