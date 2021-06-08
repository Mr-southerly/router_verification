#---------------------------------------------#
#      TCL script for a mini regression       #
#---------------------------------------------#
onbreak resume
onerror resume

#set environment variables
set DUT_SRC .
set TB_SRC .

#clean the environment and remove trash files
set delfiles [glob work *.log *.ucdb sim.list]

file delete -force {*}$delfiles

#compile the design and dut with a filelist
vlib work
vlog -sv -cover bst -timescale=1ps/1ps -l comp.log ${DUT_SRC}/router.v
vlog -sv -timescale=1ps/1ps -l comp.log ${TB_SRC}/{router_packet.sv,router_test_top.sv}

# prepare simrun folder
set timetag [clock format [clock seconds] -format "%Y%b%d-%H_%M"]
file mkdir regr_ucdb_${timetag}

# simulate with specific testname sequentially
set TestSets { {single_channel_directed_da_test 0} \
                {dual_channel_directed_da_test 1} \
                {dual_channel_random_da_test 2} \
                {all_channel_random_da_test 3} 
              }


  set testname single_channel_directed_da_test
  set LoopNum 5
  for {set loop 0} {$loop < $LoopNum} {incr loop} {
    set seed [expr int(rand() * 100)]
    echo simulating $testname
    echo $seed +TESTNAME=$testname -l regr_ucdb_${timetag}/run_${testname}_${seed}.log
    vsim -onfinish stop -cover -cvgperinstance -cvgmergeinstances -sv_seed $seed \
         +TESTNAME=$testname -l regr_ucdb_${timetag}/run_${testname}_${seed}.log work.router_test_top
    run -all
    coverage save regr_ucdb_${timetag}/${testname}_${seed}.ucdb
    quit -sim
  }

  
  
  set testname dual_channel_random_da_test
  set LoopNum 5
  for {set loop 0} {$loop < $LoopNum} {incr loop} {
    set seed [expr int(rand() * 100)]
    echo simulating $testname
    echo $seed +TESTNAME=$testname -l regr_ucdb_${timetag}/run_${testname}_${seed}.log
    vsim -onfinish stop -cover -cvgperinstance -cvgmergeinstances -sv_seed $seed \
         +TESTNAME=$testname -l regr_ucdb_${timetag}/run_${testname}_${seed}.log work.router_test_top
    run -all
    coverage save regr_ucdb_${timetag}/${testname}_${seed}.ucdb
    quit -sim
  }


  set testname all_channel_random_da_test
  set LoopNum 5
  for {set loop 0} {$loop < $LoopNum} {incr loop} {
    set seed [expr int(rand() * 100)]
    echo simulating $testname
    echo $seed +TESTNAME=$testname -l regr_ucdb_${timetag}/run_${testname}_${seed}.log
    vsim -onfinish stop -cover -cvgperinstance -cvgmergeinstances -sv_seed $seed \
         +TESTNAME=$testname -l regr_ucdb_${timetag}/run_${testname}_${seed}.log work.router_test_top
    run -all
    coverage save regr_ucdb_${timetag}/${testname}_${seed}.ucdb
    quit -sim
  }


# merge the ucdb per test
vcover merge -testassociated regr_ucdb_${timetag}/regr_${timetag}.ucdb {*}[glob regr_ucdb_${timetag}/*.ucdb]

#quit -f
