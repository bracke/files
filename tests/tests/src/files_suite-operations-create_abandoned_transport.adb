separate (Files_Suite.Operations)
   procedure Create_Abandoned_Transport (Report : String; Path : out Files.Types.UString) is
      Arguments   : Hostkit.String_Vectors.Vector;
      Exit_Status : Integer;
      File        : Ada.Text_IO.File_Type;
   begin
      Arguments.Append (To_Unbounded_String ("--files-test-abandon-transport"));
      Arguments.Append (To_Unbounded_String (Report));
      Assert
        (Hostkit.Process.Run (Hostkit.Fs.Own_Executable, Arguments, Exit_Status)
         and then Exit_Status = 0,
         "the crash fixture creates a transport and exits without finalization");
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Report);
      Path := To_Unbounded_String (Ada.Text_IO.Get_Line (File));
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Create_Abandoned_Transport;
