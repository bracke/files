separate (Check_All.Check_Swallowing_Handlers)
   procedure Check_File (Path : String) is
      Code  : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
      package Line_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);
      Lines : Line_Vectors.Vector;

      function Indent (Line : String) return Natural is
      begin
         for Index in Line'Range loop
            if Line (Index) /= ' ' then
               return Index - Line'First;
            end if;
         end loop;
         return Line'Length;
      end Indent;

      function Blank (Line : String) return Boolean is (Indent (Line) = Line'Length);

      function Trimmed (Line : String) return String is (Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both));

      --  Whether Text (lower case, trimmed) starts with the reserved word Word.
      function Starts_With_Word (Text : String; Word : String) return Boolean is
        (Text'Length >= Word'Length
         and then Text (Text'First .. Text'First + Word'Length - 1) = Word
         and then (Text'Length = Word'Length
                   or else Text (Text'First + Word'Length) not in 'a' .. 'z' | '0' .. '9' | '_'));

      --  Whether a statement line opens, continues or closes a compound
      --  statement (if, case, a loop, a block, select), whose contents run
      --  on some paths only, or not at the handler's top level.
      function Opens_Nested (Line : String) return Boolean is
         Text  : constant String := Ada.Characters.Handling.To_Lower (Trimmed (Line));
         Colon : constant Natural := Ada.Strings.Fixed.Index (Text, ":");
         function Opens (Words : String) return Boolean is
           (Starts_With_Word (Words, "if") or else Starts_With_Word (Words, "elsif")
            or else Starts_With_Word (Words, "else") or else Starts_With_Word (Words, "then")
            or else Starts_With_Word (Words, "case") or else Starts_With_Word (Words, "when")
            or else Starts_With_Word (Words, "loop") or else Starts_With_Word (Words, "for")
            or else Starts_With_Word (Words, "while") or else Starts_With_Word (Words, "declare")
            or else Starts_With_Word (Words, "begin") or else Starts_With_Word (Words, "exception")
            or else Starts_With_Word (Words, "select") or else Starts_With_Word (Words, "or")
            or else Starts_With_Word (Words, "end"));
         --  Whether the text before the colon is a statement label.
         function Labelled return Boolean is
         begin
            for C of Trimmed (Text (Text'First .. Colon - 1)) loop
               if C not in 'a' .. 'z' | '0' .. '9' | '_' then
                  return False;
               end if;
            end loop;
            return True;
         end Labelled;
      begin
         --  A named loop or block: "Search : loop".
         return Opens (Text)
           or else (Colon > Text'First
                    and then Colon < Text'Last
                    and then Text (Colon + 1) /= '='
                    and then Labelled
                    and then Opens (Trimmed (Text (Colon + 1 .. Text'Last))));
      end Opens_Nested;

      procedure Refuse (At_Line : Positive; Why : String) is
      begin
         Put_Line
           (Standard_Error, Path & ":" & Ada.Strings.Fixed.Trim (At_Line'Image, Ada.Strings.Left) & ": " & Why);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Refuse;

      First : Positive := Code'First;
   begin
      for Index in Code'Range loop
         if Code (Index) = ASCII.LF then
            Lines.Append (Code (First .. Index - 1));
            First := Index + 1;
         end if;
      end loop;
      if First <= Code'Last then
         Lines.Append (Code (First .. Code'Last));
      end if;
      for Number in Lines.First_Index .. Lines.Last_Index loop
         declare
            Line   : constant String := Lines (Number);
            Text   : constant String := Trimmed (Line);
            Arrow  : constant Natural := Ada.Strings.Fixed.Index (Text, "=>");
            Margin : constant Natural := Indent (Line);
         begin
            if Text'Length > 5 and then Text (Text'First .. Text'First + 4) = "when " and then Arrow > 0 then
               declare
                  --  The choice parameter, if named: "when E : others =>".
                  Colon   : constant Natural := Ada.Strings.Fixed.Index (Text (Text'First .. Arrow), ":");
                  Name    : constant String :=
                    (if Colon = 0 then "" else Trimmed (Text (Text'First + 5 .. Colon - 1)));
                  Handler : Boolean := False;
                  --  "when others" carries anything on; a named choice
                  --  ("when E : Name_Error") only what it names.
                  Others_Of : constant Boolean :=
                    Ada.Strings.Fixed.Index
                      (Ada.Characters.Handling.To_Lower (Text (Text'First .. Arrow)), "others") > 0;
                  --  The handler's top-level statements: what it does on
                  --  every path, outside any if, case, loop or block.
                  Nested : Boolean := Opens_Nested (Text (Arrow + 2 .. Text'Last));
                  Top_Of : Unbounded_String :=
                    (if Nested then Null_Unbounded_String else To_Unbounded_String (Text (Arrow + 2 .. Text'Last)));
                  Last_Statement : Unbounded_String :=
                    To_Unbounded_String (Trimmed (Text (Arrow + 2 .. Text'Last)));
               begin
                  --  An exception handler: the nearest line above at a
                  --  smaller indent is "exception" (other choices between).
                  for Above in reverse Lines.First_Index .. Number - 1 loop
                     if not Blank (Lines (Above)) and then Indent (Lines (Above)) < Margin then
                        Handler := Trimmed (Lines (Above)) = "exception";
                        exit;
                     end if;
                  end loop;
                  if Handler then
                     for Below in Number + 1 .. Lines.Last_Index loop
                        exit when not Blank (Lines (Below)) and then Indent (Lines (Below)) <= Margin;
                        if not Blank (Lines (Below)) then
                           Last_Statement := To_Unbounded_String (Trimmed (Lines (Below)));
                           --  A line at the statements' own indent starts a
                           --  statement; a deeper one continues it, or sits
                           --  inside the compound statement it opened.
                           if Indent (Lines (Below)) <= Margin + 3 then
                              Nested := Opens_Nested (Lines (Below));
                           end if;
                           if not Nested then
                              Append (Top_Of, ASCII.LF & Lines (Below));
                           end if;
                        end if;
                     end loop;
                     declare
                        --  Code only, lower case, and without pragma
                        --  Unreferenced, which names an occurrence to say
                        --  it is not used.
                        function Without_Unreferenced (Text : String) return String is
                           At_Pragma : constant Natural := Ada.Strings.Fixed.Index (Text, "pragma unreferenced");
                           Stop      : Natural;
                        begin
                           if At_Pragma = 0 then
                              return Text;
                           end if;
                           Stop := Ada.Strings.Fixed.Index (Text (At_Pragma .. Text'Last), ";");
                           if Stop = 0 then
                              Stop := Text'Last;
                           end if;
                           return Text (Text'First .. At_Pragma - 1)
                             & Without_Unreferenced (Text (Stop + 1 .. Text'Last));
                        end Without_Unreferenced;
                        Statements : constant String :=
                          Without_Unreferenced (Ada.Characters.Handling.To_Lower (To_String (Top_Of)));

                        --  What a handler that carries on does, on every
                        --  path, with what it caught: notes it
                        --  (Files.Diagnostics.Note), or keeps it for a caller
                        --  (Save_Occurrence). Naming it in some other way --
                        --  a comparison, an assignment, Footnote (E, ...) --
                        --  is not noting it.
                        function Hands_On (Occurrence : String) return Boolean is
                           --  The statements without blanks or line breaks,
                           --  so a call reads the same however it is laid out.
                           Squeezed : String (1 .. Statements'Length);
                           Last     : Natural := 0;
                           function Has (Text : String) return Boolean is
                             (Last > 0 and then Ada.Strings.Fixed.Index (Squeezed (1 .. Last), Text) > 0);

                           --  A call of Diagnostics.Note (qualified, as
                           --  Files.Diagnostics.Note or Diagnostics.Note)
                           --  with the occurrence: not a Note of some other
                           --  name that merely ends in "note".
                           function Notes return Boolean is
                              Call    : constant String := "diagnostics.note(" & Occurrence & ",";
                              From    : Positive := 1;
                              At_Call : Natural;
                           begin
                              while From <= Last loop
                                 At_Call := Ada.Strings.Fixed.Index (Squeezed (1 .. Last), Call, From);
                                 exit when At_Call = 0;
                                 if At_Call = 1 or else Squeezed (At_Call - 1) not in 'a' .. 'z' | '0' .. '9' | '_'
                                 then
                                    return True;
                                 end if;
                                 From := At_Call + 1;
                              end loop;
                              return False;
                           end Notes;
                        begin
                           for C of Statements loop
                              if C not in ' ' | ASCII.LF | ASCII.CR | ASCII.HT then
                                 Last := Last + 1;
                                 Squeezed (Last) := C;
                              end if;
                           end loop;
                           return Notes
                             or else Has ("note_event_loop(" & Occurrence & ")")
                             --  Reported to the user, as a startup error is.
                             or else Has ("exception_message(" & Occurrence & ")")
                             or else Has ("exception_information(" & Occurrence & ")")
                             or else (Has ("save_occurrence(") and then Has ("," & Occurrence & ")"));
                        end Hands_On;
                        --  Re-raising counts only as what the handler ends
                        --  with: a raise inside an if leaves the other path
                        --  carrying on, silently.
                        Final_Line : constant String :=
                          Ada.Characters.Handling.To_Lower (To_String (Last_Statement));
                        --  The last statement of that line: "Close (F); raise;".
                        Before_Final : constant Natural :=
                          (if Final_Line'Length > 1
                           then Ada.Strings.Fixed.Index
                             (Final_Line (Final_Line'First .. Final_Line'Last - 1), ";", Ada.Strings.Backward)
                           else 0);
                        Ends : constant String :=
                          Trimmed (Final_Line ((if Before_Final = 0 then Final_Line'First else Before_Final + 1)
                                               .. Final_Line'Last));
                        Re_Raised : constant Boolean :=
                          (Ends'Length >= 5 and then Ends (Ends'First .. Ends'First + 4) = "raise")
                          or else Ada.Strings.Fixed.Index (Ends, "reraise_occurrence") > 0;
                     begin
                        if Re_Raised then
                           null;
                        elsif Name = "" then
                           if Others_Of then
                              Refuse (Number, "a 'when others' handler carries on without noting what it caught");
                           end if;
                        elsif not Hands_On (Ada.Characters.Handling.To_Lower (Name)) then
                           Refuse (Number, "a handler names " & Name & " and carries on without using it");
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Check_File;
