separate (Check_All.Check_Clock_Arithmetic)
   procedure Collect (Path : String) is
      Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
   begin
      for Type_Name of String_List'
        [To_Unbounded_String ("Ada.Real_Time.Time"), To_Unbounded_String ("Ada.Calendar.Time")]
      loop
         declare
            Pattern : constant String := To_String (Type_Name);
            At_Type : Natural := Ada.Strings.Fixed.Index (Code, Pattern);
         begin
            while At_Type /= 0 loop
               declare
                  After : constant Positive := At_Type + Pattern'Length;
                  Colon : Natural := At_Type - 1;
               begin
                  --  The whole type name, not Time_Span or Time_First.
                  if After > Code'Last
                    or else Code (After) not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '.'
                  then
                     --  Back over "constant", "aliased" and blanks to the colon.
                     while Colon >= Code'First and then Code (Colon) /= ':'
                       and then Code (Colon) not in ';' | '(' | ASCII.LF
                     loop
                        Colon := Colon - 1;
                     end loop;
                     if Colon >= Code'First and then Code (Colon) = ':' then
                        declare
                           Last  : Natural := Colon - 1;
                           First : Natural;
                        begin
                           while Last >= Code'First and then Code (Last) = ' ' loop
                              Last := Last - 1;
                           end loop;
                           First := Last;
                           while First > Code'First
                             and then Code (First - 1) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_'
                           loop
                              First := First - 1;
                           end loop;
                           if Last >= First and then First >= Code'First then
                              Time_Names.Include (Ada.Characters.Handling.To_Lower (Code (First .. Last)));
                           end if;
                        end;
                     end if;
                  end if;
                  exit when After > Code'Last;
                  At_Type := Ada.Strings.Fixed.Index (Code (After .. Code'Last), Pattern);
               end;
            end loop;
         end;
      end loop;
   end Collect;
