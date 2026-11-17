separate (Check_All)
   procedure Check_Refused_Is_Not_Absent is
      --  Exists and Entry_Exists answer "not there" when the host refuses
      --  the lookup, so a decision built on either can take a refusal for
      --  absence. Files.Fs_Primitives.Entry_Is_Absent tells the two apart.
      --  Read as tokens, so a call split over lines or written positively
      --  ("if Exists then keep else forget") is seen as well as a negated one.

      --  The units that remove, unregister, forget, retire or undo when what
      --  they point at is gone. Each body is read with its subunits
      --  (<stem>-*.adb). In them every Exists / Entry_Exists call carries a
      --  "--  refusal-safe: <why>" comment on its line or in the comment
      --  block just above it, saying why a refusal cannot lose anything there.
      Units : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("src/files-file_system-recovery.adb"),
         To_Unbounded_String ("src/files-file_system-delete_transport_entry.adb"),
         To_Unbounded_String ("src/files-file_system-delete_verified_entry.adb"),
         To_Unbounded_String ("src/files-file_system-rename_item.adb"),
         To_Unbounded_String ("src/files-file_system-execute_drop_import.adb"),
         To_Unbounded_String ("src/files-job_context.adb"),
         To_Unbounded_String ("src/files-job_transports.adb"),
         To_Unbounded_String ("src/files-job_scavenger.adb"),
         To_Unbounded_String ("src/files-job_cleanup.adb"),
         To_Unbounded_String ("src/files-process_jobs.adb"),
         To_Unbounded_String ("src/files-operations.adb"),
         To_Unbounded_String ("src/files-operation_jobs.adb"),
         To_Unbounded_String ("src/files-history_journal.adb")];

      Annotation : constant String := "--  refusal-safe:";

      function Is_Existence_Name (Item : Tokens.Token) return Boolean is
        (Tokens.Is_Word (Item, "exists") or else Tokens.Is_Word (Item, "entry_exists"));

      function Line_Image (Line : Positive) return String is
        (Ada.Strings.Fixed.Trim (Positive'Image (Line), Ada.Strings.Left));

      --  No second name for Exists or Entry_Exists anywhere in src: a
      --  renaming hides the calls from the rule below.
      procedure Check_Renamings (Path : String) is
         Toks : constant Tokens.Token_List :=
           Tokens.Tokens_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
      begin
         for Index in 1 .. Toks.Last_Index loop
            if Tokens.Is_Word (Toks (Index), "renames") and then Index < Toks.Last_Index then
               declare
                  Name_Last : constant Positive := Tokens.Past_Name_Prefix (Toks, Index + 1);
               begin
                  if Name_Last > Index and then Is_Existence_Name (Toks (Name_Last)) then
                     Report
                       (Path & ":" & Line_Image (Toks (Index).Line)
                        & ": a renaming of " & To_String (Toks (Name_Last).Text)
                        & " hides its calls from the refused-is-not-absent check; call "
                        & "Files.Fs_Primitives.Entry_Is_Absent or Entry_Exists by name");
                  end if;
               end;
            end if;
         end loop;
      end Check_Renamings;

      package Line_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

      procedure Check_File (Path : String) is
         Text  : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
         Toks  : constant Tokens.Token_List := Tokens.Tokens_Of (Text);
         Lines : Line_Vectors.Vector;

         procedure Collect (Line : String; Number : Positive) is
            pragma Unreferenced (Number);
         begin
            Lines.Append (Line);
         end Collect;

         function Is_Comment (Line : String) return Boolean is
           (Ada.Strings.Fixed.Index (Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both), "--") = 1);

         --  The call's own line, or the comment block right above it, says
         --  why a refusal is safe there.
         function Annotated (Line : Positive) return Boolean is
            Index : Natural := Line;
         begin
            if Line <= Natural (Lines.Length)
              and then Ada.Strings.Fixed.Index (Lines (Line), Annotation) > 0
            then
               return True;
            end if;
            loop
               Index := Index - 1;
               exit when Index = 0 or else not Is_Comment (Lines (Index));
               if Ada.Strings.Fixed.Index (Lines (Index), Annotation) > 0 then
                  return True;
               end if;
            end loop;
            return False;
         end Annotated;
      begin
         For_Each_Line (Text, Collect'Access);
         for Index in 1 .. Toks.Last_Index loop
            if Is_Existence_Name (Toks (Index))
              and then Index < Toks.Last_Index
              and then Tokens.Is_Symbol (Toks (Index + 1), "(")
              and then (Index = 1
                        or else not (Tokens.Is_Word (Toks (Index - 1), "function")
                                     or else Tokens.Is_Word (Toks (Index - 1), "procedure")))
              and then not Annotated (Toks (Index).Line)
            then
               Report
                 (Path & ":" & Line_Image (Toks (Index).Line) & ": " & To_String (Toks (Index).Text)
                  & " decides here without saying why a refused lookup cannot lose anything; ask "
                  & "Files.Fs_Primitives.Entry_Is_Absent (gone for sure), a kind (Directory_Exists, "
                  & "File_Exists), or say why with '" & Annotation & " <why>'");
            end if;
         end loop;
      end Check_File;
   begin
      For_Each_Ada_Source (Root & "/src", Check_Renamings'Access);
      for Unit of Units loop
         declare
            Base : constant String := Root & "/" & To_String (Unit);
            Dir  : constant String := Ada.Directories.Containing_Directory (Base);
            Stem : constant String := Ada.Directories.Base_Name (Base);
         begin
            --  A guard on a unit that was renamed or split away guards nothing.
            if not Project_Tools.Files.File_Exists (Base) then
               Report ("guarded unit is missing: " & Base & " (refused-is-not-absent)");
            else
               Check_File (Base);
               for Subunit of Project_Tools.Files.List_Tree (Dir, Stem & "-?*.adb", Generated_Directories) loop
                  Check_File (To_String (Subunit));
               end loop;
            end if;
         end;
      end loop;
   end Check_Refused_Is_Not_Absent;
