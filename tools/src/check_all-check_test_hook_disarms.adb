separate (Check_All)
   procedure Check_Test_Hook_Disarms is
      use Tokens;

      --  A process-wide test hook: the procedure of Files.<Unit>.Testing that
      --  arms it and the one that disarms it. Where both are one procedure,
      --  Off is the argument that disarms it ("false", "0"), and a call with
      --  any other arms it.
      type Hook is record
         Unit   : Unbounded_String;
         Arm    : Unbounded_String;
         Disarm : Unbounded_String;
         Off    : Unbounded_String;
      end record;

      function Pair (Unit, Arm, Disarm : String; Off : String := "") return Hook is
        (Unit   => To_Unbounded_String (Unit),
         Arm    => To_Unbounded_String (Arm),
         Disarm => To_Unbounded_String (Disarm),
         Off    => To_Unbounded_String (Off));

      type Hook_List is array (Positive range <>) of Hook;

      --  Every hook of the Testing specs in tests/tests/src, which
      --  Check_Hook_Table below holds this list to.
      Hooks : constant Hook_List :=
        [Pair ("durability", "fail_syncs_ending_with", "clear"),
         Pair ("durability", "fail_stage_sync", "clear"),
         Pair ("file_identities", "set_unavailable", "set_unavailable", Off => "false"),
         Pair ("file_system", "refuse_native_trash", "refuse_native_trash", Off => "false"),
         Pair ("file_system", "change_source_after_copy", "stop_changing_source"),
         Pair ("file_system", "change_trashed_after_copy", "stop_changing_trashed"),
         Pair ("file_system", "fail_directory_restore", "stop_failing_directory_restore"),
         Pair ("file_system", "fail_owned_delete", "stop_failing_owned_delete"),
         Pair ("file_system", "refuse_creation_matches", "refuse_creation_matches", Off => "false"),
         Pair ("file_system", "pause_sweep_work", "resume_sweep_work"),
         Pair ("file_system", "watch_ownership_changes", "stop_watching_ownership_changes"),
         Pair ("folder_size", "fail_result_reads", "fail_result_reads", Off => "0"),
         Pair ("fs_primitives", "refuse_lookups", "stop_refusing_lookups"),
         Pair ("journal", "refuse_reads", "refuse_reads", Off => "0"),
         Pair ("operation", "fail_after_merge", "stop_failing_after_merge"),
         Pair ("operations", "fake_checkpoint_clock", "fake_checkpoint_clock", Off => "false"),
         Pair ("path_references", "simulate_folding_host", "simulate_folding_host", Off => "false"),
         Pair ("process", "refuse_next_launch", "clear_refusal"),
         Pair ("trash", "refuse_native_trash", "refuse_native_trash", Off => "false"),
         Pair ("undo_recording", "count_undo_records", "count_undo_records", Off => "false"),
         Pair ("undo_recording", "fake_checkpoint_clock", "fake_checkpoint_clock", Off => "false")];

      --  How a Testing procedure that arms something is named: one of these
      --  starts its name.
      Arming_Prefixes : constant String_List :=
        [To_Unbounded_String ("refuse_"),
         To_Unbounded_String ("fail_"),
         To_Unbounded_String ("pause_"),
         To_Unbounded_String ("fake_"),
         To_Unbounded_String ("simulate_"),
         To_Unbounded_String ("watch_"),
         To_Unbounded_String ("change_"),
         To_Unbounded_String ("count_"),
         To_Unbounded_String ("set_unavailable")];

      --  Arming procedures that arm one object rather than the process (unit
      --  and name): nothing is left armed for the next test once the object
      --  is gone.
      Per_Object : constant String_List := [1 => To_Unbounded_String ("process.simulate_failed_stop")];

      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");

      procedure Refuse (Message : String) is
      begin
         Report (Message);
      end Refuse;

      function Word_At (Toks : Token_List; Index : Natural; Text : String) return Boolean is
        (Index in Toks.First_Index .. Toks.Last_Index and then Is_Word (Toks (Index), Text));

      function Symbol_At (Toks : Token_List; Index : Natural; Text : String) return Boolean is
        (Index in Toks.First_Index .. Toks.Last_Index and then Is_Symbol (Toks (Index), Text));

      --  Whether Toks (Index) names <Unit>.Testing.<Name> (whatever comes
      --  before <Unit>), and not as an attribute's prefix.
      function Names (Toks : Token_List; Index : Positive; Unit, Name : String) return Boolean is
        (Index >= Toks.First_Index + 4
         and then Word_At (Toks, Index, Name)
         and then Is_Symbol (Toks (Index - 1), ".")
         and then Is_Word (Toks (Index - 2), "testing")
         and then Is_Symbol (Toks (Index - 3), ".")
         and then Is_Word (Toks (Index - 4), Unit)
         and then not Symbol_At (Toks, Index + 1, "'"));

      --  Whether the call named at Toks (Index) takes the one word Text as
      --  its first argument.
      function First_Argument_Is (Toks : Token_List; Index : Positive; Text : String) return Boolean is
        (Symbol_At (Toks, Index + 1, "(")
         and then Index + 3 <= Toks.Last_Index
         and then Toks (Index + 2).Kind = Word
         and then To_String (Toks (Index + 2).Text) = Text
         and then (Is_Symbol (Toks (Index + 3), ",") or else Is_Symbol (Toks (Index + 3), ")")));

      function Arms (Toks : Token_List; Index : Positive; Item : Hook) return Boolean is
        (Names (Toks, Index, To_String (Item.Unit), To_String (Item.Arm))
         and then (Item.Off = Null_Unbounded_String
                   or else not First_Argument_Is (Toks, Index, To_String (Item.Off))));

      function Disarms (Toks : Token_List; Index : Positive; Item : Hook) return Boolean is
        (Names (Toks, Index, To_String (Item.Unit), To_String (Item.Disarm))
         and then (Item.Off = Null_Unbounded_String
                   or else First_Argument_Is (Toks, Index, To_String (Item.Off))));

      function Disarms_In (Toks : Token_List; From, To : Natural; Item : Hook) return Boolean is
        (for some Index in Natural'Max (From, Toks.First_Index) .. Natural'Min (To, Toks.Last_Index) =>
            Disarms (Toks, Index, Item));

      --  A construct "end" closes, by the indices of its tokens: its start,
      --  its "begin" (0 before it has one, and for one that has none), its
      --  "exception" (0 for none) and its "end".
      type Frame_Kind is (Subprogram, Program_Unit, Block, Other);

      type Frame is record
         Kind    : Frame_Kind := Other;
         Name    : Unbounded_String;
         Start   : Positive := 1;
         Body_At : Natural := 0;
         Handler : Natural := 0;
         Stop    : Natural := 0;
      end record;

      package Frame_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Frame);

      --  Whether the "procedure", "function" or "entry" at From begins a
      --  body: an "is" at its own depth before any ";", and not "is new",
      --  "is separate", "is abstract", "is null", "is <>" or an expression
      --  function's "is (" or "is [". One in a parameter list (an access to
      --  a subprogram) ends at the ")" that closes the list.
      function Opens_Subprogram_Body (Toks : Token_List; From : Positive) return Boolean is
         Depth : Integer := 0;
      begin
         for Index in From + 1 .. Toks.Last_Index loop
            if Is_Symbol (Toks (Index), "(") then
               Depth := Depth + 1;
            elsif Is_Symbol (Toks (Index), ")") then
               Depth := Depth - 1;
               if Depth < 0 then
                  return False;
               end if;
            elsif Depth = 0 and then (Is_Symbol (Toks (Index), ";") or else Is_Word (Toks (Index), "renames")) then
               return False;
            elsif Depth = 0 and then Is_Word (Toks (Index), "is") then
               return not (Word_At (Toks, Index + 1, "new")
                           or else Word_At (Toks, Index + 1, "separate")
                           or else Word_At (Toks, Index + 1, "abstract")
                           or else Word_At (Toks, Index + 1, "null")
                           or else Symbol_At (Toks, Index + 1, "(")
                           or else Symbol_At (Toks, Index + 1, "[")
                           or else Symbol_At (Toks, Index + 1, "<"));
            end if;
         end loop;
         return False;
      end Opens_Subprogram_Body;

      --  Whether the "package", "task" or "protected" at From begins a unit
      --  that "end" closes: an "is" before any ";", and not "is separate"
      --  nor a package's "is new".
      function Opens_Program_Unit (Toks : Token_List; From : Positive) return Boolean is
         Depth : Integer := 0;
      begin
         for Index in From + 1 .. Toks.Last_Index loop
            if Is_Symbol (Toks (Index), "(") then
               Depth := Depth + 1;
            elsif Is_Symbol (Toks (Index), ")") then
               Depth := Depth - 1;
            elsif Depth = 0 and then (Is_Symbol (Toks (Index), ";") or else Is_Word (Toks (Index), "renames")) then
               return False;
            elsif Depth = 0 and then Is_Word (Toks (Index), "is") then
               return not Word_At (Toks, Index + 1, "separate")
                 and then not (Is_Word (Toks (From), "package") and then Word_At (Toks, Index + 1, "new"));
            end if;
         end loop;
         return False;
      end Opens_Program_Unit;

      --  Every construct of Toks that "end" closes, in the order of their
      --  ends; Balanced is False when an "end" closes nothing or a construct
      --  is left open, and the structure could not be followed.
      procedure Parse (Toks : Token_List; Frames : out Frame_Vectors.Vector; Balanced : out Boolean) is
         Stack : Frame_Vectors.Vector;
         Index : Positive := Toks.First_Index;
         --  The "begin"s still to come of declare expressions, which no
         --  "end" closes.
         Expression_Begins : Natural := 0;

         procedure Push (Kind : Frame_Kind; Started : Boolean; Name : String := "") is
         begin
            Stack.Append
              (Frame'
                 (Kind    => Kind,
                  Name    => To_Unbounded_String (Name),
                  Start   => Index,
                  Body_At => (if Started then Index else 0),
                  Handler => 0,
                  Stop    => 0));
         end Push;

         function Awaits_Begin return Boolean is
           (not Stack.Is_Empty and then Stack.Last_Element.Kind /= Other and then Stack.Last_Element.Body_At = 0);
      begin
         Frames.Clear;
         Balanced := True;
         while Index <= Toks.Last_Index loop
            if Toks (Index).Kind = Word then
               declare
                  Text       : constant String := To_String (Toks (Index).Text);
                  After_End  : constant Boolean := Word_At (Toks, Index - 1, "end");
                  After_Open : constant Boolean := Symbol_At (Toks, Index - 1, "(");
               begin
                  if Text = "procedure" or else Text = "function" or else Text = "entry" then
                     if not After_End and then Opens_Subprogram_Body (Toks, Index) then
                        Push
                          (Subprogram,
                           Started => False,
                           Name    => (if Index < Toks.Last_Index then To_String (Toks (Index + 1).Text) else ""));
                     end if;
                  elsif Text = "package"
                    or else ((Text = "task" or else Text = "protected")
                             and then not Word_At (Toks, Index - 1, "access"))
                  then
                     if not After_End and then Opens_Program_Unit (Toks, Index) then
                        Push (Program_Unit, Started => False);
                     end if;
                  elsif Text = "declare" then
                     if After_Open then
                        Expression_Begins := Expression_Begins + 1;
                     else
                        Push (Block, Started => False);
                     end if;
                  elsif Text = "begin" then
                     if Expression_Begins > 0 then
                        Expression_Begins := Expression_Begins - 1;
                     elsif Awaits_Begin then
                        Stack (Stack.Last_Index).Body_At := Index;
                     else
                        Push (Block, Started => True);
                     end if;
                  elsif Text = "if" or else Text = "case" then
                     --  Not a conditional or case expression, which no "end" closes.
                     if not After_End and then not After_Open then
                        Push (Other, Started => True);
                     end if;
                  elsif Text = "loop" or else Text = "select" or else Text = "do" then
                     if not After_End then
                        Push (Other, Started => True);
                     end if;
                  elsif Text = "record" then
                     if not After_End and then not Word_At (Toks, Index - 1, "null") then
                        Push (Other, Started => True);
                     end if;
                  elsif Text = "exception" then
                     --  Not the declaration of one ("Failed : exception;").
                     if not Symbol_At (Toks, Index - 1, ":")
                       and then not Stack.Is_Empty
                       and then Stack.Last_Element.Kind /= Other
                       and then Stack.Last_Element.Body_At > 0
                     then
                        Stack (Stack.Last_Index).Handler := Index;
                     end if;
                  elsif Text = "end" then
                     if Stack.Is_Empty then
                        Balanced := False;
                        return;
                     end if;
                     declare
                        Closed : Frame := Stack.Last_Element;
                     begin
                        Closed.Stop := Index;
                        Frames.Append (Closed);
                        Stack.Delete_Last;
                     end;
                     if Word_At (Toks, Index + 1, "if")
                       or else Word_At (Toks, Index + 1, "loop")
                       or else Word_At (Toks, Index + 1, "case")
                       or else Word_At (Toks, Index + 1, "select")
                       or else Word_At (Toks, Index + 1, "record")
                       or else Word_At (Toks, Index + 1, "return")
                     then
                        Index := Index + 1;
                     end if;
                  end if;
               end;
            end if;
            Index := Index + 1;
         end loop;
         Balanced := Stack.Is_Empty;
      end Parse;

      --  The index of the ";" that ends the statement at From, at its own
      --  parenthesis depth; past the end when none does.
      function Statement_End (Toks : Token_List; From : Positive) return Positive is
         Depth : Integer := 0;
         Next  : Positive := From;
      begin
         while Next <= Toks.Last_Index loop
            if Is_Symbol (Toks (Next), "(") then
               Depth := Depth + 1;
            elsif Is_Symbol (Toks (Next), ")") then
               Depth := Depth - 1;
            elsif Depth = 0 and then Is_Symbol (Toks (Next), ";") then
               return Next;
            end if;
            Next := Next + 1;
         end loop;
         return Next;
      end Statement_End;

      --  Whether Toks (From .. To) disarm Item: by its disarm itself, or by
      --  calling a subprogram declared inside Within that does.
      function Reaches
        (Toks   : Token_List;
         Frames : Frame_Vectors.Vector;
         Within : Frame;
         From   : Natural;
         To     : Natural;
         Item   : Hook) return Boolean is
      begin
         if Disarms_In (Toks, From, To, Item) then
            return True;
         end if;
         for Callee of Frames loop
            if Callee.Kind = Subprogram
              and then Within.Start < Callee.Start
              and then Callee.Stop < Within.Stop
              and then Disarms_In (Toks, Callee.Start, Callee.Stop, Item)
              and then (for some Index in From .. Natural'Min (To, Toks.Last_Index) =>
                          Toks (Index).Kind = Word and then Toks (Index).Text = Callee.Name)
            then
               return True;
            end if;
         end loop;
         return False;
      end Reaches;

      --  A guard type, and a hook its Finalize disarms.
      type Guard is record
         Type_Name : Unbounded_String;
         Disarmed  : Positive := 1;
      end record;

      package Guard_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Guard);

      --  Each Finalize body of Toks, with the type it finalizes (the last
      --  name before the ")" of its parameter) and each hook it disarms.
      procedure Collect_Guards (Toks : Token_List; Into : in out Guard_Vectors.Vector) is
         Frames   : Frame_Vectors.Vector;
         Balanced : Boolean;
      begin
         Parse (Toks, Frames, Balanced);
         --  A source that cannot be followed is refused by Problem.
         if not Balanced then
            return;
         end if;
         for Finalizer of Frames loop
            if Finalizer.Kind = Subprogram and then Finalizer.Name = "finalize" then
               for Close in Finalizer.Start .. Finalizer.Stop loop
                  if Is_Symbol (Toks (Close), ")") then
                     if Close > Finalizer.Start + 1 and then Toks (Close - 1).Kind = Word then
                        for Which in Hooks'Range loop
                           if Disarms_In (Toks, Finalizer.Start, Finalizer.Stop, Hooks (Which)) then
                              Into.Append (Guard'(Type_Name => Toks (Close - 1).Text, Disarmed => Which));
                           end if;
                        end loop;
                     end if;
                     exit;
                  end if;
               end loop;
            end if;
         end loop;
      end Collect_Guards;

      --  Whether the arming of Hooks (Which) at Toks (Index) is undone on the
      --  failure path: by a handler of a construct around it, by the handler
      --  of a block right after it, or by a guard object a subprogram around
      --  it declares.
      function Covered
        (Toks   : Token_List;
         Frames : Frame_Vectors.Vector;
         Guards : Guard_Vectors.Vector;
         Index  : Positive;
         Which  : Positive) return Boolean
      is
         Item      : constant Hook := Hooks (Which);
         Outermost : Frame;
         Enclosed  : Boolean := False;
         Next      : constant Positive := Statement_End (Toks, Index) + 1;

         function Around (Span : Frame) return Boolean is (Span.Start < Index and then Index < Span.Stop);
      begin
         --  The test itself: its own subprograms are what a handler may call.
         for Candidate of Frames loop
            if Candidate.Kind = Subprogram
              and then Around (Candidate)
              and then (not Enclosed or else Candidate.Start < Outermost.Start)
            then
               Outermost := Candidate;
               Enclosed := True;
            end if;
         end loop;

         for Construct of Frames loop
            if Around (Construct)
              and then Construct.Handler > Index
              and then Reaches
                (Toks, Frames, (if Enclosed then Outermost else Construct), Construct.Handler, Construct.Stop, Item)
            then
               return True;
            end if;
         end loop;

         if Word_At (Toks, Next, "begin") or else Word_At (Toks, Next, "declare") then
            for Construct of Frames loop
               if Construct.Start = Next
                 and then Construct.Handler > 0
                 and then Reaches
                   (Toks, Frames, (if Enclosed then Outermost else Construct), Construct.Handler, Construct.Stop,
                    Item)
               then
                  return True;
               end if;
            end loop;
         end if;

         --  A guard object declared by a subprogram around the arming (and
         --  not by one nested in that subprogram).
         for Declarer of Frames loop
            if Declarer.Kind = Subprogram and then Around (Declarer) then
               for Colon in Declarer.Start .. (if Declarer.Body_At > 0 then Declarer.Body_At else Index) loop
                  if Is_Symbol (Toks (Colon), ":")
                    and then not (for some Nested of Frames =>
                                    Nested.Kind = Subprogram
                                    and then Declarer.Start < Nested.Start
                                    and then Nested.Start <= Colon
                                    and then Colon <= Nested.Stop)
                  then
                     declare
                        Type_At : Positive := Colon + 1;
                     begin
                        while Word_At (Toks, Type_At, "aliased") or else Word_At (Toks, Type_At, "constant") loop
                           Type_At := Type_At + 1;
                        end loop;
                        Type_At := Past_Name_Prefix (Toks, Type_At);
                        if Type_At <= Toks.Last_Index
                          and then Toks (Type_At).Kind = Word
                          and then (for some Known of Guards =>
                                      Known.Disarmed = Which and then Known.Type_Name = Toks (Type_At).Text)
                        then
                           return True;
                        end if;
                     end;
                  end if;
               end loop;
            end if;
         end loop;
         return False;
      end Covered;

      --  What is wrong with Toks, the source of a test, or "": a hook armed
      --  and not disarmed on the failure path, or a use clause or renaming
      --  of a Testing package with hooks, which would hide their calls.
      function Problem (Toks : Token_List; Guards : Guard_Vectors.Vector) return String is
         Frames   : Frame_Vectors.Vector;
         Balanced : Boolean;
      begin
         for Index in Toks.First_Index .. Toks.Last_Index loop
            --  "use type" makes only operators visible, which hide no call.
            if (Is_Word (Toks (Index), "use")
                and then not Word_At (Toks, Index + 1, "type")
                and then not Word_At (Toks, Index + 1, "all"))
              or else Is_Word (Toks (Index), "renames")
            then
               declare
                  Next : Positive := Index + 1;
               begin
                  while Next + 2 <= Toks.Last_Index
                    and then Toks (Next).Kind = Word
                    and then Is_Symbol (Toks (Next + 1), ".")
                  loop
                     for Item of Hooks loop
                        if Is_Word (Toks (Next), To_String (Item.Unit))
                          and then Is_Word (Toks (Next + 2), "testing")
                        then
                           return "line" & Toks (Index).Line'Image & ": a use clause or renaming of Files."
                             & To_String (Item.Unit) & ".Testing hides its hooks' calls; name them in full";
                        end if;
                     end loop;
                     Next := Next + 2;
                  end loop;
               end;
            end if;
         end loop;

         Parse (Toks, Frames, Balanced);
         if not Balanced then
            return "its begin/end structure could not be followed to find its exception handlers";
         end if;
         for Index in Toks.First_Index .. Toks.Last_Index loop
            for Which in Hooks'Range loop
               if Arms (Toks, Index, Hooks (Which)) and then not Covered (Toks, Frames, Guards, Index, Which) then
                  return "line" & Toks (Index).Line'Image & ": " & To_String (Hooks (Which).Arm)
                    & " is armed with no exception handler (of the test, or of the block right after it) that calls "
                    & To_String (Hooks (Which).Disarm)
                    & (if Hooks (Which).Off = Null_Unbounded_String then ""
                       else " (" & To_String (Hooks (Which).Off) & ")")
                    & ", and no guard object whose Finalize does: a failure leaves it armed for the tests after it";
               end if;
            end loop;
         end loop;
         return "";
      end Problem;

      --  Every hook-arming procedure of the Testing specs is paired here (or
      --  listed as arming one object), and every pair names procedures the
      --  specs declare: a new hook cannot slip past this check unpaired.
      procedure Check_Hook_Table is
         Declared : Name_Sets.Set;
         Suffix   : constant String := "-testing.ads";

         function Looks_Like_Arming (Name : String) return Boolean is
           (for some Prefix of Arming_Prefixes => Starts_With (Name, To_String (Prefix)));

         function Paired (Unit, Name : String) return Boolean is
           (for some Item of Hooks => To_String (Item.Unit) = Unit and then To_String (Item.Arm) = Name);

         function Arms_One_Object (Unit, Name : String) return Boolean is
           (for some Item of Per_Object => To_String (Item) = Unit & "." & Name);
      begin
         for Spec of Project_Tools.Files.List_Tree (Root & "/tests/tests/src", "*" & Suffix, Generated_Directories) loop
            declare
               Path   : constant String := To_String (Spec);
               Simple : constant String := Ada.Directories.Simple_Name (Path);
               Stem   : constant String := Simple (Simple'First .. Simple'Last - Suffix'Length);
               Dash   : constant Natural := Ada.Strings.Fixed.Index (Stem, "-", Ada.Strings.Backward);
               Unit   : constant String := Stem (Dash + 1 .. Stem'Last);
               Toks   : constant Token_List := Tokens_Of (Project_Tools.Files.Read_Raw_File (Path));
            begin
               for Index in Toks.First_Index .. Toks.Last_Index - 1 loop
                  if Is_Word (Toks (Index), "procedure") and then Toks (Index + 1).Kind = Word then
                     declare
                        Name : constant String := To_String (Toks (Index + 1).Text);
                     begin
                        Declared.Include (Unit & "." & Name);
                        if Looks_Like_Arming (Name) and then not Paired (Unit, Name)
                          and then not Arms_One_Object (Unit, Name)
                        then
                           Refuse
                             (Path & ": " & Name & " looks like it arms a test hook; pair it with its disarm in "
                              & "check_all's Check_Test_Hook_Disarms, or list it there as arming one object");
                        end if;
                     end;
                  end if;
               end loop;
            end;
         end loop;
         for Item of Hooks loop
            for Name of String_List'[Item.Arm, Item.Disarm] loop
               if not Declared.Contains (To_String (Item.Unit) & "." & To_String (Name)) then
                  Refuse
                    ("check_all's Check_Test_Hook_Disarms pairs " & To_String (Item.Arm) & " with "
                     & To_String (Item.Disarm) & ", but no Files." & To_String (Item.Unit)
                     & ".Testing spec in tests/tests/src declares " & To_String (Name));
               end if;
            end loop;
         end loop;
      end Check_Hook_Table;

      --  The check itself, on every shape it exists for: if it stopped
      --  telling them apart, the tree search below would pass on every test.
      type Sample is record
         Text    : Unbounded_String;
         Flagged : Boolean;
      end record;

      function Make (Text : String; Flagged : Boolean) return Sample is
        (Text => To_Unbounded_String (Text), Flagged => Flagged);

      type Sample_List is array (Positive range <>) of Sample;

      LF : constant Character := ASCII.LF;

      Samples : constant Sample_List :=
        [Make ("procedure Test is" & LF & "begin" & LF
               & "   Files.IO.Durability.Testing.Fail_Stage_Sync;" & LF & "   Check;" & LF
               & "   Files.IO.Durability.Testing.Clear;" & LF & "end Test;",
               Flagged => True),
         Make ("procedure Test is" & LF & "begin" & LF
               & "   Files.IO.Durability.Testing.Fail_Stage_Sync;" & LF & "   Check;" & LF
               & "   Files.IO.Durability.Testing.Clear;" & LF
               & "exception" & LF & "   when others =>" & LF
               & "      Files.IO.Durability.Testing.Clear;" & LF & "      raise;" & LF & "end Test;",
               Flagged => False),
         Make ("procedure Test is" & LF & "begin" & LF
               & "   Files.File_Identities.Testing.Set_Unavailable (True);" & LF
               & "   begin" & LF & "      Check;" & LF
               & "      Files.File_Identities.Testing.Set_Unavailable (False);" & LF
               & "   exception" & LF & "      when others =>" & LF
               & "         Files.File_Identities.Testing.Set_Unavailable (False);" & LF & "         raise;" & LF
               & "   end;" & LF & "end Test;",
               Flagged => False),
         Make ("procedure Test is" & LF
               & "   procedure Cleanup is" & LF & "   begin" & LF
               & "      Files.Operations.Undo_Recording.Testing.Count_Undo_Records (False);" & LF & "   end Cleanup;"
                 & LF
               & "   procedure Prepare is" & LF & "   begin" & LF
               & "      Files.Operations.Undo_Recording.Testing.Count_Undo_Records (True);" & LF & "   end Prepare;"
                 & LF
               & "begin" & LF & "   Prepare;" & LF & "   if Ready then" & LF & "      Check;" & LF & "   end if;" & LF
               & "   Cleanup;" & LF
               & "exception" & LF & "   when others =>" & LF & "      Cleanup;" & LF & "      raise;" & LF
               & "end Test;",
               Flagged => False),
         Make ("procedure Test is" & LF & "begin" & LF
               & "   Files.Folder_Size.Testing.Fail_Result_Reads (3);" & LF & "   Check;" & LF
               & "exception" & LF & "   when others =>" & LF
               & "      Files.Jobs.Process.Testing.Clear_Refusal;" & LF & "      raise;" & LF & "end Test;",
               Flagged => True),
         Make ("type Launch_Guard is new Ada.Finalization.Limited_Controlled with null record;" & LF
               & "overriding procedure Finalize (Guard : in out Launch_Guard) is" & LF & "begin" & LF
               & "   Files.Jobs.Process.Testing.Clear_Refusal;" & LF & "end Finalize;" & LF
               & "procedure Test is" & LF & "   Guard : Launch_Guard;" & LF & "begin" & LF
               & "   Files.Jobs.Process.Testing.Refuse_Next_Launch;" & LF & "   Check;" & LF & "end Test;",
               Flagged => False),
         Make ("procedure Test is" & LF & "begin" & LF
               & "   Files.File_System.Testing.Refuse_Native_Trash (False);" & LF & "end Test;",
               Flagged => False),
         Make ("procedure Test is" & LF & "begin" & LF
               & "   Files.File_System.Testing.Refuse_Native_Trash (Refuse);" & LF
               & "   for Item of Items loop" & LF & "      Check (Item);" & LF & "   end loop;" & LF
               & "exception" & LF & "   when others =>" & LF
               & "      Files.File_System.Testing.Refuse_Native_Trash (True);" & LF & "      raise;" & LF
               & "end Test;",
               Flagged => True),
         Make ("procedure Test is" & LF & "   use Files.IO.Durability.Testing;" & LF & "begin" & LF
               & "   null;" & LF & "end Test;",
               Flagged => True)];

      Guards : Guard_Vectors.Vector;
   begin
      for Index in Samples'Range loop
         declare
            Toks         : constant Token_List := Tokens_Of (To_String (Samples (Index).Text));
            Sample_Guard : Guard_Vectors.Vector;
         begin
            Collect_Guards (Toks, Sample_Guard);
            if (Problem (Toks, Sample_Guard) /= "") /= Samples (Index).Flagged then
               Refuse
                 ("check_all's Check_Test_Hook_Disarms no longer tells its sample" & Natural'Image (Index)
                  & (if Samples (Index).Flagged then " from a disarmed hook" else " from an armed one"));
            end if;
         end;
      end loop;

      Check_Hook_Table;

      for Source of Project_Tools.Files.List_Tree (Root & "/tests/tests/src", "files_suite*.ad?", Generated_Directories)
      loop
         Collect_Guards (Tokens_Of (Project_Tools.Files.Read_Raw_File (To_String (Source))), Guards);
      end loop;
      for Source of Project_Tools.Files.List_Tree (Root & "/tests/tests/src", "files_suite*.adb", Generated_Directories)
      loop
         declare
            Found : constant String :=
              Problem (Tokens_Of (Project_Tools.Files.Read_Raw_File (To_String (Source))), Guards);
         begin
            if Found /= "" then
               Refuse (To_String (Source) & ": " & Found);
            end if;
         end;
      end loop;
   end Check_Test_Hook_Disarms;
