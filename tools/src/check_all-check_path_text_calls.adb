separate (Check_All)
   procedure Check_Path_Text_Calls is
   begin
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories) loop
         declare
            Path  : constant String := To_String (Item);
            Lower : constant String :=
              Ada.Characters.Handling.To_Lower
                (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True));
            Simple : constant String := "ada.directories.simple_name (";
            From   : Positive := Lower'First;
            At_Simple : Natural;
            Bad    : Boolean :=
              Ada.Strings.Fixed.Index (Lower, "ada.directories.containing_directory (") > 0
              or else Ada.Strings.Fixed.Index (Lower, "ada.directories.compose (") > 0;
         begin
            loop
               At_Simple := Ada.Strings.Fixed.Index (Lower (From .. Lower'Last), Simple);
               exit when At_Simple = 0;
               if Ada.Strings.Fixed.Index
                    (Lower (At_Simple + Simple'Length .. Natural'Min (Lower'Last, At_Simple + Simple'Length + 40)),
                     "directory_entry =>") /= At_Simple + Simple'Length
               then
                  Bad := True;
               end if;
               exit when At_Simple + Simple'Length > Lower'Last;
               From := At_Simple + Simple'Length;
            end loop;
            if Bad then
               Put_Line
                 (Standard_Error,
                  Path & ": reads a path with Ada.Directories (Simple_Name, Containing_Directory, Compose);"
                  & " use Files.Fs_Primitives or Hostkit.Fs.Join");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
   end Check_Path_Text_Calls;
