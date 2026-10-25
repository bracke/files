separate (Files.File_System)
function Permission_String
  (Path       : String;
   Kind       : Files.Types.Item_Kind;
   Mode_Bits  : Natural;
   Mode_Known : Boolean)
   return String
is
   Result : String (1 .. 3) := "---";

   --  The shared Kind_From_Path classifier reaches Executable_Item by
   --  asking Hostkit.Fs.Is_Executable and
   --  Regular_File_Item by the same question answering False, so for those
   --  two the answer is already in Kind. A directory and a special file are
   --  not ordinary files, which is what Is_Executable requires, so it answers False
   --  for them without being asked.
   --
   --  A symlink is the case the classifiers never ask about: they stop at
   --  Symlink_Item before reaching the executable test, and Is_Executable
   --  follows the link. Unknown_Item comes from a classifier that raised, so
   --  it settles nothing either. Both still ask.
   --
   --  Worth the coupling because Is_Executable is three stats on Linux
   --  (Exists, Kind, Is_Executable_File) and this made it six per listed
   --  file. Test_Permission_String_Agrees_With_The_Host pins it: if a
   --  classifier ever stops implying the answer, that fails rather than the
   --  permission column quietly going wrong.
   Ask_The_Host : constant Boolean :=
     Kind in Files.Types.Symlink_Item | Files.Types.Unknown_Item;

   Executable : constant Boolean :=
     (if Ask_The_Host
      then Hostkit.Fs.Is_Executable (Path)
      else Kind = Files.Types.Executable_Item);
begin
   --  Read and write come out of the mode already read for this item, where
   --  that mode is the host's own bits. Asking
   --  GNAT.OS_Lib.Is_Owner_Readable_File and Is_Owner_Writable_File is two
   --  more stats of a path just stat-ed, for two bits that stat returned.
   --
   --  Mode_Known is what keeps it honest: on Windows the mode is Hostkit
   --  rendering an ACL into POSIX shape rather than a field the filesystem
   --  stores, and GNAT answers these from something else again, so there the
   --  host keeps being asked.
   --
   --  Test_Permission_String_Agrees_With_The_Host walks the mode matrix
   --  asserting both positions against those same GNAT calls, so a host where
   --  this disagrees with them fails rather than showing a quietly wrong
   --  column.
   if Mode_Known then
      if (Mode_Bits / 8#400#) mod 2 = 1 then
         Result (1) := 'r';
      end if;

      if (Mode_Bits / 8#200#) mod 2 = 1 then
         Result (2) := 'w';
      end if;
   else
      if GNAT.OS_Lib.Is_Owner_Readable_File (Path) then
         Result (1) := 'r';
      end if;

      if GNAT.OS_Lib.Is_Owner_Writable_File (Path) then
         Result (2) := 'w';
      end if;
   end if;
   if Executable then
      Result (3) := 'x';
   end if;

   return Result;
exception
   when others =>
      return "";
end Permission_String;
