quit -sim
vlog -sv *.sv 
vsim -coverage -voptargs="+acc" $1
add wave *
run $2