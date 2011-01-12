# Support for Zaber motorized linear stages
#
# Copyright (C) 2011, Corpus Callosum Corporation.  All Rights Reserverd.

Zaber : module
{
	PATH:		con "/dis/lib/zaber.dis";

	Creset,
	Chome,
	Crenumber:	con iota;

	Cmovetracking,
	Climitactive,
	Cmanualmove:	con (8+iota);
	
	Cstorecurrentpos,
	Cstoredposition,
	Cmovetostoredpos:	con (16+iota);

	Cmoveabsolute:	con 20;
	Cmoverelative:	con 21;
	Cmoveconstantspeed:	con 22;
	Cstop:		con 23;

	Cmemory,
	Crestore,
	Csetresolution,
	Csetrunningcurrent,
	Csetholdcurrent,
	Csetmode:	con (35+iota);

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
	Cecho:		con (42+iota);

	Cposition:		con 60;

	Cerror:		con 255;


	Instruction: adt
	{
		id:		int;
		com:		int;
		data:		array of byte;

		bytes:	fn(inst: self ref Instruction): array of byte;
	};
	
	Device: adt
	{
		id:		int;
		conn:	ref Connection;

		write:	fn(d: self ref Device, c: int, data: array of byte): int;
	};
	
	Connection: adt
	{
		path:	string;
		rfd:	ref Sys->FD;
		wfd:	ref Sys->FD;

		write:	fn(c: self ref Connection, i: ref Instruction): int;
	};

	open:	fn(path: string): ref Connection;
};
