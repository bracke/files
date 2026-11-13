separate (Check_All)
   procedure Check_No_User_Text_Literals (Path : String) is
      Content       : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Index         : Natural := Content'First;
      Line          : Natural := 1;

      --  Advance Index past the developer-diagnostic pragma statement that begins
      --  at Index, tracking parenthesis depth so a ';' inside its message string
      --  does not end it early, and counting newlines for accurate line numbers.
      procedure Skip_Diagnostic_Pragma is
         Depth : Integer := 0;
      begin
         while Index <= Content'Last loop
            if Content (Index) = ASCII.LF then
               Line := Line + 1;
               Index := Index + 1;
            elsif Content (Index) = '"' then
               Index := Index + 1;
               while Index <= Content'Last loop
                  if Content (Index) = '"' then
                     if Index < Content'Last and then Content (Index + 1) = '"' then
                        Index := Index + 2;
                     else
                        Index := Index + 1;
                        exit;
                     end if;
                  else
                     if Content (Index) = ASCII.LF then
                        Line := Line + 1;
                     end if;
                     Index := Index + 1;
                  end if;
               end loop;
            elsif Content (Index) = '(' then
               Depth := Depth + 1;
               Index := Index + 1;
            elsif Content (Index) = ')' then
               Depth := Depth - 1;
               Index := Index + 1;
            elsif Content (Index) = ';' and then Depth = 0 then
               Index := Index + 1;
               exit;
            else
               Index := Index + 1;
            end if;
         end loop;
      end Skip_Diagnostic_Pragma;
   begin
      while Index <= Content'Last loop
         if Content (Index) = ASCII.LF then
            Line := Line + 1;
            Index := Index + 1;
         elsif Content (Index) = '-'
           and then Index < Content'Last
           and then Content (Index + 1) = '-'
         then
            --  Skip the rest of a comment line: its prose may contain quoted
            --  phrases that are documentation, not hard-coded user-visible
            --  string literals. (Outside a string literal, "--" always starts
            --  an Ada comment.)
            while Index <= Content'Last and then Content (Index) /= ASCII.LF loop
               Index := Index + 1;
            end loop;
         elsif Diagnostic_Pragma_Length (Content, Index) > 0 then
            Skip_Diagnostic_Pragma;
         elsif Is_Source_String_Delimiter (Content, Index) then
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
                     if Content (Index) = ASCII.LF then
                        Line := Line + 1;
                     end if;
                     Append (Literal, Content (Index));
                     Index := Index + 1;
                  end if;
               end loop;

               if Looks_Like_User_Text (To_String (Literal)) then
                  Put_Line
                    (Standard_Error,
                     Path & ":" & Natural'Image (Line)
                     & ": hard-coded user-visible text literal: "
                     & To_String (Literal));
                  Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                  raise Program_Error;
               end if;
            end;
         else
            Index := Index + 1;
         end if;
      end loop;
   end Check_No_User_Text_Literals;
