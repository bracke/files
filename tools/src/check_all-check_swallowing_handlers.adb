separate (Check_All)
   procedure Check_Swallowing_Handlers is
      use Tokens;

      --  The line of the first handler in Source that swallows what it
      --  caught, or 0 when none does.
      --  @param Source Ada source text.
      --  @param Why What that handler does, for the refusal.
      --  @return Its line number, or 0.
      function Swallowed (Source : String; Why : out Unbounded_String) return Natural is separate;

      LF : constant Character := ASCII.LF;

      --  A body whose one handler does Handler.
      function Handling (Handler : String) return String is
        ("begin" & LF & "   Work;" & LF & "exception" & LF & Handler & LF & "end;");

      --  The lint itself, on the handlers it exists for (Refused) and on
      --  the ones it must let pass (Quiet): a note or a raise only spelled
      --  in a message or a comment is none.
      type Sample_List is array (Positive range <>) of Unbounded_String;
      Refused : constant Sample_List :=
        [To_Unbounded_String (Handling ("   when others =>" & LF & "      null;")),
         To_Unbounded_String
           (Handling ("   when E : others =>" & LF & "      Put_Line (""Files.Diagnostics.Note (E, What)"");")),
         To_Unbounded_String
           (Handling ("   when E : others =>" & LF & "      null;  --  Files.Diagnostics.Note (E, ""What"");")),
         To_Unbounded_String (Handling ("   when others =>" & LF & "      Put_Line (""Done; raise"");"))];
      Quiet : constant Sample_List :=
        [To_Unbounded_String (Handling ("   when E : others =>" & LF & "      Files.Diagnostics.Note (E, ""What"");")),
         To_Unbounded_String
           (Handling ("   when E : others =>" & LF & "      Files.Diagnostics.Note" & LF & "        (E," & LF
                      & "         ""What"");")),
         To_Unbounded_String (Handling ("   when others =>" & LF & "      raise Program_Error with ""a; b"";")),
         To_Unbounded_String (Handling ("   when Constraint_Error =>" & LF & "      null;"))];

      procedure Fail (Message : String) is
      begin
         Put_Line (Standard_Error, Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      Why : Unbounded_String;
   begin
      for Index in Refused'Range loop
         if Swallowed (To_String (Refused (Index)), Why) = 0 then
            Fail ("check_all's Check_Swallowing_Handlers no longer sees the handler in its sample"
                  & Natural'Image (Index));
         end if;
      end loop;
      for Index in Quiet'Range loop
         if Swallowed (To_String (Quiet (Index)), Why) /= 0 then
            Fail ("check_all's Check_Swallowing_Handlers refuses its quiet sample" & Natural'Image (Index) & ": "
                  & To_String (Why));
         end if;
      end loop;

      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories) loop
         declare
            Path : constant String := To_String (Item);
            Name : constant String := Ada.Directories.Simple_Name (Path);
         begin
            if Name not in "files-diagnostics.ads" | "files-diagnostics.adb"
              and then Name not in "files-environment.ads" | "files-environment.adb"
            then
               declare
                  Line : constant Natural := Swallowed (To_String (Project_Tools.Text.Read_Text_File (Path)), Why);
               begin
                  if Line /= 0 then
                     Fail (Path & ":" & Ada.Strings.Fixed.Trim (Line'Image, Ada.Strings.Left) & ": " & To_String (Why));
                  end if;
               end;
            end if;
         end;
      end loop;
   end Check_Swallowing_Handlers;
