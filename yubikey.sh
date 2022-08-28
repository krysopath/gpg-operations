#!/bin/bash

XDOTOOL=$(which xdotool || echo echo xdotool)
YKMAN=$(which ykman || echo echo YKMAN)
CFG=$(cat $BACKUP_PATH/data.yaml)
WIN=$($XDOTOOL getactivewindow)

err_report() {
    echo "Error on line $1"
    #pkill -9 $(pgrep xdotool)
    reset
}

trap 'err_report $LINENO' 1 2 3 4 9

_minimal_config() {
    printf "admin
kdf-setup
$(yq ".$serial.default_admin" <<<"$CFG")
lang
en
$(yq ".$serial.default_admin" <<<"$CFG")
login
$(yq ".$serial.holder.login" <<<"$CFG")
name
$(yq ".$serial.holder.surename" <<<"$CFG")
$(yq ".$serial.holder.givenname" <<<"$CFG")
key-attr
2
1
2
1
$(yq ".$serial.default_admin" <<<"$CFG")
2
1
$(yq ".$serial.default_admin" <<<"$CFG")
q
"
}

to_xdo() {
    printf "$1" | sed -e 's/./& /g' -e 's/-/ minus /g' | sed ':a;N;$!ba;s/\n/ Return /g'
}

run_xdo() {
    xdotool key --window $WIN --clearmodifiers --delay 100 $*
}

run_smartcard_script() {
    (
        while read line; do
            sleep 2
            run_xdo "$(to_xdo "$line") Return"
            sleep 2
        done < <(echo "$1")
    )&
    gpg --edit-card

}

if test $1 = "smartcard"; then
	run_smartcard_script "$(_minimal_config)"
elif test $1 = "ykman"; then
	for serial in $($YKMAN list --serials); do
	    default_admin=$(yq ".$serial.default_admin" <<<"$CFG")

	    if $(yq ".$serial.config?.timeout|length > 0" <<<"$CFG"); then
		    echo "$serial: setting OTP touch timeout"
		    $YKMAN -d $serial config usb --force --chalresp-timeout "$(yq ".$serial.config.timeout" <<<"$CFG")"
	    fi

	    if $(yq ".$serial.oath.lock_new|length > 0" <<<"$CFG"); then
		    echo "$serial: setting OATH access password"
		    $YKMAN -d $serial oath access change \
			    --password $(yq ".$serial.oath.lock" <<<"$CFG") \
			    --new-password $(yq ".$serial.oath.lock_new" <<<"$CFG")
	    fi
	
	    if $(yq ".$serial.config.new_lock // false" <<<"$CFG"); then
	        echo "$serial: setting config lock code"
	        $YKMAN -d $serial config set-lock-code \
	            --force \
	            --lock-code $(yq ".$serial.access.lock" <<<"$CFG") \
	            --new-lock-code $(yq ".$serial.access.new_lock" <<<"$CFG")
	    fi
	
	    for slot in 1 2; do
	        for app in $(yq ".$serial.$slot // {}|keys|to_entries|.[]|(.value)" <<<"$CFG"); do
	            if test $app = "openpgp"; then

	        	echo "$serial: $app: setting PIN retries"
	                $YKMAN -d $serial $app access set-retries \
				--force --admin-pin $default_admin \
				$(yq ".$serial.$slot.$app.access.retries" <<<"$CFG")
	
	                if "$(yq ".$serial.$slot.$app.keys.touch // {}|keys|to_entries|length > 0" <<<"$CFG")"; then
	                    for key in $(yq -o=json \
	                        ".$serial.$slot.$app.keys.touch // {}|keys|to_entries" <<<"$CFG" \
	                        | jq -r '.[]| "\(.value)"'); do

			    	pol=$(yq ".$serial.$slot.$app.keys.touch.$key" <<<"$CFG")
	        		echo "$serial: $app: setting $key key touch policy: $pol"
	                        $YKMAN -d $serial $app keys set-touch \
					--force --admin-pin $default_admin \
					$key $pol
	                    done
	
	                fi
	            fi
	            if test $app = "otp"; then
	
	                for feature in $(yq ".$serial.$slot.$app // {}|keys|to_entries|.[]|(.value)" <<<"$CFG"); do
	        	    echo "$serial: $app: setting $feature"
	                    $YKMAN -d $serial $app $feature $slot --force $(yq ".$serial.$slot.$app.$feature.key" <<<"$CFG")
	                done
	
	            fi
	        done
	    done
	done
fi
