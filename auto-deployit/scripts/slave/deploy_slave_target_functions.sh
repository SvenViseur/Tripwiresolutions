#!/bin/bash
#### The above line allows this file to be the first part of a script
#### that uses these functions. It does not mean this file is executable
#### in itself.

#### Deze functies kunnen gebruikt worden op target machines.
#### Daartoe kan dit script meegenomen worden in de scripts die naar
#### de target machines gestuurd wordt. Merk op dat deze file niet
#### op een blijvende manier op de target machines zal staan. Het
#### kan enkel in het kader van een specifiek script meegestuurd worden.

keep_historical_versions() {
## Input: $keepfname          : de filename waarvan historische versies
##                              behouden moeten worden.
##        $sudouser           : de user (via sudo su) die de files kan
##                              wijzigen.
## Output: None
##          De file $keepfname wordt bewaard met suffix .old1, en eventuele
##          bestaande .old* versies worden doorgeschoven tot max 9 versies.
if [[ "$keepfname" = "" ]]; then
  echo "ERROR: function keep_historical_versions called with empty keepfname."
  exit 16
fi
if [[ "$sudouser" = "" ]]; then
  echo "ERROR: function keep_historical_versions called with empty sudouser."
  exit 16
fi
## Omdat de sudo commando's vanuit een ander pad vertrekken, moeten we de
## filename naar een absoluut pad omzetten
local abskeepfname=$(readlink -f $keepfname)

if [ -e "${abskeepfname}.old9" ]; then
  rm -f "${abskeepfname}.old9"
fi
if [ -e "${abskeepfname}.old8" ]; then
  sudo /bin/su - ${sudouser} -c "mv ${abskeepfname}.old8 ${abskeepfname}.old9"
fi
if [ -e "${abskeepfname}.old7" ]; then
  sudo /bin/su - ${sudouser} -c "mv ${abskeepfname}.old7 ${abskeepfname}.old8"
fi
if [ -e "${abskeepfname}.old6" ]; then
  sudo /bin/su - ${sudouser} -c "mv ${abskeepfname}.old6 ${abskeepfname}.old7"
fi
if [ -e "${abskeepfname}.old5" ]; then
  sudo /bin/su - ${sudouser} -c "mv ${abskeepfname}.old5 ${abskeepfname}.old6"
fi
if [ -e "${abskeepfname}.old4" ]; then
  sudo /bin/su - ${sudouser} -c "mv ${abskeepfname}.old4 ${abskeepfname}.old5"
fi
if [ -e "${abskeepfname}.old3" ]; then
  sudo /bin/su - ${sudouser} -c "mv ${abskeepfname}.old3 ${abskeepfname}.old4"
fi
if [ -e "${abskeepfname}.old2" ]; then
  sudo /bin/su - ${sudouser} -c "mv ${abskeepfname}.old2 ${abskeepfname}.old3"
fi
if [ -e "${abskeepfname}.old1" ]; then
  sudo /bin/su - ${sudouser} -c "mv ${abskeepfname}.old1 ${abskeepfname}.old2"
fi
if [ -e "${abskeepfname}" ]; then
  sudo /bin/su - ${sudouser} -c "mv ${abskeepfname}      ${abskeepfname}.old1"
fi

}
