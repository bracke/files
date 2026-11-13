separate (Check_All)
   procedure Run_And_Require_Output
     (Label           : String;
      Dir             : String;
      Program         : String;
      Args            : GNAT.OS_Lib.Argument_List;
      Output_Path     : String;
      Required_First  : String;
      Required_Second : String)
   is
      Previous    : constant String := Ada.Directories.Current_Directory;
      Spawned     : Boolean := False;
      Status      : Integer := -1;
      Output_Text : Unbounded_String;
   begin
      Project_Tools.Files.Delete_File_If_Present (Output_Path);

      Ada.Directories.Set_Directory (Dir);
      GNAT.OS_Lib.Spawn
        (Program_Name => Program,
         Args         => Args,
         Output_File  => Output_Path,
         Success      => Spawned,
         Return_Code  => Status,
         Err_To_Out   => True);
      Ada.Directories.Set_Directory (Previous);

      if not Spawned or else Status /= 0 then
         Put_Line
           (Standard_Error,
            Label & " failed with status" & Integer'Image (Status));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;

      Output_Text := Project_Tools.Text.Read_Text_File (Output_Path);
      if not Project_Tools.Text.Contains (To_String (Output_Text), Required_First)
        or else not Project_Tools.Text.Contains (To_String (Output_Text), Required_Second)
      then
         Put_Line
           (Standard_Error,
            Label & " output is missing expected CLI help text");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;

      Project_Tools.Files.Delete_File_If_Present (Output_Path);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Previous then
            Ada.Directories.Set_Directory (Previous);
         end if;
         raise;
   end Run_And_Require_Output;
