FROM antora/antora:latest

RUN npm i -g antora-site-generator-lunr
RUN npm root -g
RUN npm list -g --depth=0
