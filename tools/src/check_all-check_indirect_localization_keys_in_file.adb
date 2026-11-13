separate (Check_All)
   procedure Check_Indirect_Localization_Keys_In_File (Path : String) is
      Catalog : constant String := Root & "/share/files.catalog";
      Content : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Index   : Natural := Content'First;
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

               if Is_Indirect_Localization_Key (To_String (Literal)) then
                  Project_Tools.Files.Require_Contains
                    (Catalog,
                     "en." & To_String (Literal) & " = ",
                     Path & ": localization key must exist in share/files.catalog: " & To_String (Literal));
               end if;
            end;
         else
            Index := Index + 1;
         end if;
      end loop;
   end Check_Indirect_Localization_Keys_In_File;
