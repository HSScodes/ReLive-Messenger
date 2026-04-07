# yellows' MSNP wiki
An alternative to MSNPiki that aims to actually document things they didn't.

# Building
```
npm i
set WIKINAME=yellows' MSNP wiki
# this should be an absolute path on a domain to where the files will be put
set VPREFIX=/
set DOMAIN=example.com
mkdir build
npm run build
cp ./node_modules/yiki/yiki.css build/
```

# License
This work is licensed under the
[GNU Free Documentation License 1.3](https://www.gnu.org/licenses/fdl-1.3.en.html).
