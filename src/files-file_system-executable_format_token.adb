separate (Files.File_System)
function Executable_Format_Token (Path : String) return String is
   File   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Buffer : Ada.Streams.Stream_Element_Array (1 .. 4);
   Last   : Ada.Streams.Stream_Element_Offset;
begin
   File := Files.Fs_Primitives.Open_Regular_Read (Path);
   if File = GNAT.OS_Lib.Invalid_FD then
      return "";
   end if;
   Read_Descriptor (File, Buffer, Last);
   Close_Read_Descriptor (File);

   if Matches_Signature (Buffer, Last, ELF_Magic) then
      return "executable.format|elf";
   elsif Matches_Signature (Buffer, Last, PE_Magic) then
      return "executable.format|pe";
   elsif Matches_Signature (Buffer, Last, Script_Magic) then
      return "executable.format|script";
   else
      return "executable.format|unknown";
   end if;
exception
   when others =>
      Close_Read_Descriptor (File);
      return "";
end Executable_Format_Token;
