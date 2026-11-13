separate (Check_All)
   procedure Check_Command_Localization_Keys is
      Commands : constant String := Root & "/src/files-commands.adb";
      Catalog  : constant String := Root & "/share/files.catalog";
      Content  : constant String := To_String (Project_Tools.Text.Read_Text_File (Commands));
      Index    : Natural := Content'First;

      procedure Require_Key (Key : String) is
      begin
         if Starts_With (Key, "command.") then
            Project_Tools.Files.Require_Contains
              (Catalog,
               "en." & Key & " = ",
               "command localization key must exist in share/files.catalog: " & Key);
         end if;
      end Require_Key;
   begin
      while Index <= Content'Last loop
         if Is_Source_String_Delimiter (Content, Index) then
            Index := Index + 1;
            declare
               Literal : Unbounded_String;
               Closed  : Boolean := False;
            begin
               while Index <= Content'Last and then not Closed loop
                  if Content (Index) = '"' then
                     if Index < Content'Last and then Content (Index + 1) = '"' then
                        Append (Literal, '"');
                        Index := Index + 2;
                     else
                        Closed := True;
                        Index := Index + 1;
                     end if;
                  else
                     Append (Literal, Content (Index));
                     Index := Index + 1;
                  end if;
               end loop;

               Require_Key (To_String (Literal));
            end;
         else
            Index := Index + 1;
         end if;
      end loop;
   end Check_Command_Localization_Keys;
