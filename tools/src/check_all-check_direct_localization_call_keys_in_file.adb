separate (Check_All)
   procedure Check_Direct_Localization_Call_Keys_In_File (Path : String) is
      Content : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));

      procedure Check_Marker (Marker : String) is
         Search_From : Positive := Content'First;
      begin
         loop
            declare
               Found : constant Natural :=
                 Ada.Strings.Fixed.Index
                   (Source  => Content,
                    Pattern => Marker,
                    From    => Search_From);
            begin
               exit when Found = 0;

               declare
                  Index  : Natural := Found + Marker'Length;
                  Key    : Unbounded_String;
                  Closed : Boolean := False;
               begin
                  while Index <= Content'Last and then not Closed loop
                     if Content (Index) = '"' then
                        if Index < Content'Last and then Content (Index + 1) = '"' then
                           Append (Key, '"');
                           Index := Index + 2;
                        else
                           Closed := True;
                           Index := Index + 1;
                        end if;
                     else
                        Append (Key, Content (Index));
                        Index := Index + 1;
                     end if;
                  end loop;

                  if Is_Complete_Localization_Key (To_String (Key)) then
                     Require_Catalog_Key (Path, To_String (Key));
                  end if;

                  Search_From := Natural'Min (Index, Content'Last);
               end;
            end;
         end loop;
      end Check_Marker;
   begin
      if Content = "" then
         return;
      end if;

      Check_Marker ("Files.Localization.Text (""");
      Check_Marker ("Localized (""");
   end Check_Direct_Localization_Call_Keys_In_File;
