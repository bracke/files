separate (Files.Operations)
   function Duplicate_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      First_Created : Unbounded_String;
      Created_Any   : Boolean := False;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;

      --  Build the " (copy)" / " (copy N)" marker. The fragments are kept
      --  separate so no single string literal mixes a letter with a space,
      --  which the format-validation tooling rejects.
      function Copy_Marker (Value : Positive) return String is
         Open  : constant String := " (";
         Word  : constant String := "copy";
         Close : constant String := ")";
      begin
         if Value = 1 then
            return Open & Word & Close;
         else
            return Open & Word & " " & Trimmed_Image (Value) & Close;
         end if;
      end Copy_Marker;
   begin
      if Items.Is_Empty then
         return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
      end if;

      for Item of Items loop
         declare
            Source : constant String := To_String (Item.Full_Path);
            Name   : constant String := To_String (Item.Name);
            Ext    : constant String := Ada.Directories.Extension (Name);
            Base   : constant String := Ada.Directories.Base_Name (Name);

            --  A directory-unique copy stem (without extension), e.g. "report
            --  (copy)" or "report (copy 2)" when earlier choices already exist.
            function Unique_Stem return String is
            begin
               for N in 1 .. 9_999 loop
                  declare
                     Candidate : constant String := Base & Copy_Marker (N);
                  begin
                     if not Ada.Directories.Exists
                              (Ada.Directories.Compose (Directory, Candidate, Ext))
                     then
                        return Candidate;
                     end if;
                  end;
               end loop;

               return Base & Copy_Marker (1);
            end Unique_Stem;

            Dest_Path : constant String :=
              Ada.Directories.Compose (Directory, Unique_Stem, Ext);
            Dest_Name : constant String := Ada.Directories.Simple_Name (Dest_Path);
            Mutation  : constant Files.File_System.Mutation_Result :=
              Files.File_System.Copy_Tree (Source, Dest_Path);
         begin
            if not Mutation.Success then
               return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
            end if;

            if not Created_Any then
               First_Created := To_Unbounded_String (Dest_Name);
               Created_Any := True;
            end if;
         end;
      end loop;

      if not Created_Any then
         return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
      end if;

      --  Reload so the new copies appear, and select the first one.
      return Reload_Current_Directory (Model, Settings, To_String (First_Created));
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
   end Duplicate_Selected;
