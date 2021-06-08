//Lab 4 - Task 2, Step 3
//
//Use macros as a guard against multiple includes of Packet.sv
//ToDo
`ifndef INC_PACKET_SV
`define INC_PACKET_SV
//Lab 4 - Task 2, Step 2
//
//Declare a class Packet
//ToDo
class Packet;
  //Lab 4 - Task 2, Step 4
  //
  //In the body of the class create the following properties
  //rand bit[3:0] sa, da;
  //rand logic[7:0] payload[$];
  //     string name;
  //ToDo
  rand bit[3:0] sa, da;
  rand logic[7:0] payload[$];
       string   name;
  //Lab 4 - Task 3, Step 1
  //
  //In body of the class
  //Add a constraint block to limit sa and da to 0:15 and payload.size() to 2:4
  //ToDo
  constraint valid {
  	sa inside { [0:15] };
	da inside { [0:15] };
	payload.size() inside { [2:4] };
  }
  //Lab 4 - Task 4, Step 1
  //
  //In body of the class
  //Add prototype declarations of the following methods
  //function new(string name = "Packet");
  //function bit compare(Packet pkt2cmp, ref string message);
  //function void display(string prefix = "NOTE");
  //ToDo
  extern function new(string name = "Packet");
  extern function bit compare(Packet pkt2cmp, ref string message);
  extern function void display(string prefix = "NOTE");

endclass: Packet
//Lab 4 - Task 5, Step 1
//
//Outside the class body
//Create the new() method
//ToDo
function Packet::new(string name);
  //Lab 4 - Task 5, Step 2
  //
  //Inside new() assign class property name with string passed via argument
  //ToDo
  this.name = name;
endfunction: new

//Lab 4 - Task 6, Steps 1,2,3
//
//Cut and paste the compare method from the test.sv file
//Reference the method to Packet class with ::
//Modify the argument list to add a Packet handle
//ToDo
function bit Packet::compare(Packet pkt2cmp, ref string message);

  //Lab 3 - Task 4, Step 2
  //
  //In compare() compare data payload[$] with pkt2cmp_payload[$]
  //If sizes do not match
  //   set string argument with description of error
  //   terminate subroutine by returning a 0
  //If data matches (you can directly compare arrays using ==)
  //   set string argument with description of success
  //   terminate subroutine successfully by returning a 1
  //If data does not match
  //   set string argument with description of error
  //   terminate subroutine by returning a 0
  //ToDo
  if(payload.size() != pkt2cmp.payload.size()) begin
    message = "Payload size Mismatch:\n";
    message = { message, $sformatf("payload.size() = %0d, pkt2cmp.payload.size() = %0d\n", payload.size(), pkt2cmp.payload.size()) };
    return (0);
  end
  if(payload == pkt2cmp.payload) ;
  else begin
    message = "Payload Content Mismatch:\n";
    message = { message, $sformatf("Packet Sent:   %p\nPkt Received:   %p", payload, pkt2cmp.payload) };
    return (0);
  end
  message = "Successfully Compared";
  return(1);
endfunction: compare

  //Lab 4 - Task 6, Step 4
  //
  //In compare() change all pkt2cmp_payload references to pkt2cmp.payload
  //ToDo

//Lab 4 - Task 7, Step 1
//
//Define the display() function
//Reference the method to Packet class with ::
//(you can copy the .display file from ../../solutions/lab4 instead)
//ToDo

function void Packet::display(string prefix);
  $display("[%s]%t %s sa = %0d, da = %0d", prefix, $realtime, name, sa, da);
  foreach(payload[i])
    $display("[%s]%t %s payload[%0d] = %0d", prefix, $realtime, name, i, payload[i]);
endfunction


  //Lab 4 - Task 7, Step 2
  //
  //!!! ONLY IF did not copy the .display file in Step 1 !!!
  //Inside display() print formatted content of Packet proerties
  //ToDo
`endif
