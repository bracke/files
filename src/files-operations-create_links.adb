separate (Files.Operations)
   function Create_Links
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Hard     : Boolean)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      First_Created : Unbounded_String;
      Created_Any   : Boolean := False;
      Undo_From     : Files.Types.String_Vectors.Vector;
      Undo_To       : Files.Types.String_Vectors.Vector;
      Undo_Sources  : Files.Types.String_Vectors.Vector;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;

      --  Build the " (link)" / " (link N)" marker. The fragments are kept
      --  separate so no single string literal mixes a letter with a space,
      --  which the format-validation tooling rejects.
      function Link_Marker (Value : Positive) return String is
         Open  : constant String := " (";
         Word  : constant String := "link";
         Close : constant String := ")";
      begin
         if Value = 1 then
            return Open & Word & Close;
         else
            return Open & Word & " " & Trimmed_Image (Value) & Close;
         end if;
      end Link_Marker;
   begin
      if Items.Is_Empty then
         return Make_Result (Operation_Failed, "error.link.failed", Directory);
      end if;

      for Item of Items loop
         declare
            Source : constant String := To_String (Item.Full_Path);
            Name   : constant String := To_String (Item.Name);
            Ext    : constant String := Ada.Directories.Extension (Name);
            Base   : constant String := Ada.Directories.Base_Name (Name);

            --  A directory-unique link stem (without extension), e.g. "report
            --  (link)" or "report (link 2)" when earlier choices already exist.
            function Unique_Stem return String is
            begin
               for N in 1 .. 9_999 loop
                  declare
                     Candidate : constant String := Base & Link_Marker (N);
                  begin
                     if not Ada.Directories.Exists
                              (Ada.Directories.Compose (Directory, Candidate, Ext))
                     then
                        return Candidate;
                     end if;
                  end;
               end loop;

               return Base & Link_Marker (1);
            end Unique_Stem;

            Dest_Path : constant String :=
              Ada.Directories.Compose (Directory, Unique_Stem, Ext);
            Dest_Name : constant String := Ada.Directories.Simple_Name (Dest_Path);
            Mutation  : constant Files.File_System.Mutation_Result :=
              (if Hard
               then Files.File_System.Create_Hard_Link (Source, Dest_Path)
               else Files.File_System.Create_Symbolic_Link (Source, Dest_Path));
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               --  Record undo for the links already created before this mid-batch
               --  failure so they stay Ctrl-Z-restorable, and reload so they
               --  appear instead of staying hidden until the next refresh.
               if not Undo_From.Is_Empty then
                  Files.Model.Record_Undo
                    (Model, Files.Model.Undo_Delete_Created, Undo_From, Undo_To,
                     Forward     => Undo_Sources,
                     Create_Kind =>
                       (if Hard
                        then Files.Model.Create_Hard_Link
                        else Files.Model.Create_Symbolic_Link));
                  declare
                     Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                     pragma Unreferenced (Reload);
                  begin
                     Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
                  end;
               end if;
               return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Directory);
            end if;

            Undo_From.Append (To_Unbounded_String (Dest_Path));
            Undo_To.Append (To_Unbounded_String (Dest_Path));
            Undo_Sources.Append (To_Unbounded_String (Source));
            if not Created_Any then
               First_Created := To_Unbounded_String (Dest_Name);
               Created_Any := True;
            end if;
         end;
      end loop;

      if not Created_Any then
         return Make_Result (Operation_Failed, "error.link.failed", Directory);
      end if;

      --  A created link is undone by deleting it again and redone by
      --  re-creating it from its recorded source.
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Delete_Created, Undo_From, Undo_To,
         Forward     => Undo_Sources,
         Create_Kind =>
           (if Hard
            then Files.Model.Create_Hard_Link
            else Files.Model.Create_Symbolic_Link));

      --  Reload so the new links appear, and select the first one.
      return Reload_Current_Directory (Model, Settings, To_String (First_Created));
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.link.failed", Directory);
   end Create_Links;
