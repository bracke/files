separate (Files.File_System)
   function Executable_Format_Token (Path : String) return String is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File   : Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4);
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Path);
      Stream_IO.Read (File, Buffer, Last);
      Stream_IO.Close (File);

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
         Safe_Close (File);
         return "";
   end Executable_Format_Token;
