separate (Check_All)
   procedure Require_Only_Names_From
     (Prefix       : String;
      Package_Name : String;
      Allowed      : String_List;
      Message      : String;
      Short_Too    : Boolean := True)
   is
      Short  : constant String :=
        Package_Name (Ada.Strings.Fixed.Index (Package_Name, ".", Ada.Strings.Backward) + 1 .. Package_Name'Last);
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;

      function Identifier_Char (C : Character) return Boolean is
        (C in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_');

      procedure Refuse (Path, What : String) is
      begin
         Put_Line (Standard_Error, Path & ": " & Message & " (" & What & ")");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Refuse;

      procedure Check (Path : String) is
         Code : constant String :=
           Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True);
         From : Positive := Code'First;
         At_Name : Natural;
      begin
         --  In full, or by the short name a child of the parent may use
         --  ("use Process_Jobs;", "package PJ renames Process_Jobs;").
         if Ada.Strings.Fixed.Index (Code, "use " & Package_Name) > 0
           or else Ada.Strings.Fixed.Index (Code, "renames " & Package_Name) > 0
           or else (Short_Too and then
                    (for some Tail of String_List'[To_Unbounded_String (";"), To_Unbounded_String (",")] =>
                      Ada.Strings.Fixed.Index (Code, "use " & Short & To_String (Tail)) > 0
                      or else Ada.Strings.Fixed.Index (Code, "renames " & Short & To_String (Tail)) > 0))
         then
            Refuse (Path, "uses or renames " & Package_Name);
         end if;
         loop
            At_Name := Ada.Strings.Fixed.Index (Code (From .. Code'Last), Short & ".");
            exit when At_Name = 0;
            declare
               First : constant Positive := At_Name + Short'Length + 1;
               Last  : Natural := First - 1;
               Parent : constant String := Package_Name (Package_Name'First .. Package_Name'Last - Short'Length);
               --  Standing alone: not the tail of a longer identifier or of
               --  another package's name.
               function Alone (Position : Positive) return Boolean is
                 (Position = Code'First
                  or else (not Identifier_Char (Code (Position - 1)) and then Code (Position - 1) /= '.'));
               --  Package_Name in full (Files.Folder_Size.), or the short
               --  name alone (Folder_Size.).
               Relevant : constant Boolean :=
                 (Short_Too and then Alone (At_Name))
                 or else (At_Name - Code'First >= Parent'Length
                          and then Code (At_Name - Parent'Length .. At_Name - 1) = Parent
                          and then Alone (At_Name - Parent'Length));
            begin
               while Last < Code'Last and then Identifier_Char (Code (Last + 1)) loop
                  Last := Last + 1;
               end loop;
               if Relevant
                 and then Last >= First
                 and then not (for some Name of Allowed => To_String (Name) = Code (First .. Last))
               then
                  Refuse (Path, Package_Name & "." & Code (First .. Last));
               end if;
               From := Natural'Max (Last, At_Name) + 1;
            end;
         end loop;
      end Check;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", Prefix & "*", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Ends_With (Name, ".ads") or else Ends_With (Name, ".adb") then
               Check (Ada.Directories.Full_Name (Item));
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Require_Only_Names_From;
