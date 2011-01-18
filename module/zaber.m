# Support for Zaber motorized linear stages
#
# Copyright (C) 2011, Corpus Callosum Corporation.  All Rights Reserverd.

Zaber : module
{
	PATH:		con "/dis/lib/zaber.dis";

	Creset,
	Chome,
	Crenumber:			con iota;

	Cmovetracking,
	Climitactive,
	Cmanualmove:		con (8+iota);
	
	Cstorecurrentpos,
	Cstoredposition,
	Cmovetostoredpos:	con (16+iota);

	Cmoveabsolute,
	Cmoverelative,
	Cmoveconstantspeed,
	Cstop:				con (20+iota);

	Cmemory,
	Crestore,
	Csetresolution,
	Csetrunningcurrent,
	Csetholdcurrent,
	Csetmode:			con (35+iota);

	Csettargetspeed,
	Csetacceleration,
	Csetmaxrange,
	Csetcurrentposition,
	Csetmaxrelativemove,
	Csethomeoffset,
	Csetaliasnumber,
	Csetlockstate,
	Cdeviceid,
	Cversion,
	Cpowersupplyv,
	Csetting,
	Cstatus,
	Cecho:				con (42+iota);

	Cposition:			con 60;

	Cerror:				con 255;


	Instruction: adt
	{
		id:		int;
		com:	int;
		data:	array of byte;

		new:	fn(d, c: int, b: array of byte): ref Instruction;
		bytes:	fn(inst: self ref Instruction): array of byte;
	};
	
	Device: adt
	{
		id:		int;
		port:	ref Port;

		write:	fn(d: self ref Device, c: int, data: array of byte): int;
	};
	
	Port: adt
	{
		lock:	ref Lock->Semaphore;
		local:	string;
		ctl:	ref Sys->FD;
		data:	ref Sys->FD;

		# input reader
		avail:	array of byte;
		pid:	int;
		
		write:	fn(c: self ref Port, i: ref Instruction): int;
	};

	init:		fn();
	open:		fn(path: string): ref Port;
	close:		fn(p: ref Port): ref Sys->Connection;
	getreply:	fn(p: ref Port, n: int): array of ref Instruction;
	readreply:	fn(p: ref Port, ms: int): ref Instruction;
	send:		fn(p: ref Port, i: ref Instruction): int;
};
