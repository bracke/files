separate (Check_All)
   procedure Check_Job_Layer is
      --  Files.Jobs sits below the file system: it reaches File_System only
      --  through the Files.Jobs.Storage port, and nothing above it at all.
      --  An allow-list: of the Files units, a Jobs source may name only its
      --  own family, Files.IO and the leaf units every layer may use, so a
      --  new unit above Jobs is refused without being listed here. The with
      --  clauses are read as tokens in every spec, body and subunit of the
      --  family, so a new unit or a split body stays covered.
      Leaf_Units : constant String_List :=
        [To_Unbounded_String ("files"),
         To_Unbounded_String ("files.types"),
         To_Unbounded_String ("files.text_case"),
         To_Unbounded_String ("files.name_parts"),
         To_Unbounded_String ("files.text_basics"),
         To_Unbounded_String ("files.text_encoding"),
         To_Unbounded_String ("files.preference_types"),
         To_Unbounded_String ("files.ui_types"),
         To_Unbounded_String ("files.command_reasons"),
         To_Unbounded_String ("files.file_system_types"),
         To_Unbounded_String ("files.path_checks"),
         To_Unbounded_String ("files.protocol_names"),
         To_Unbounded_String ("files.hex_text"),
         To_Unbounded_String ("files.timing"),
         To_Unbounded_String ("files.environment"),
         To_Unbounded_String ("files.diagnostics"),
         To_Unbounded_String ("files.file_identities"),
         To_Unbounded_String ("files.extra_info"),
         To_Unbounded_String ("files.leaf_names"),
         To_Unbounded_String ("files.folder_tree"),
         To_Unbounded_String ("files.breadcrumbs")];

      function Starts (Text, Prefix : String) return Boolean is
        (Text'Length >= Prefix'Length and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

      function Allowed (Unit : String) return Boolean is
        ((not Starts (Unit, "files.") and then Unit /= "files")
         or else Unit = "files.jobs" or else Starts (Unit, "files.jobs.")
         or else Unit = "files.io" or else Starts (Unit, "files.io.")
         or else (for some Leaf of Leaf_Units => To_String (Leaf) = Unit));

      Seen : Natural := 0;
   begin
      for Pattern of String_List'[To_Unbounded_String ("files-jobs.ad?"), To_Unbounded_String ("files-jobs-*.ad?")]
      loop
         for Item of Project_Tools.Files.List_Tree (Root & "/src", To_String (Pattern), Generated_Directories) loop
            Seen := Seen + 1;
            for Unit of Tokens.With_Units_Of (Project_Tools.Files.Read_Raw_File (To_String (Item))) loop
               if not Allowed (To_String (Unit)) then
                  Report
                    (To_String (Item) & ": the jobs layer names " & To_String (Unit)
                     & ", which is neither Files.Jobs, Files.IO nor a leaf unit");
               end if;
            end loop;
         end loop;
      end loop;
      --  No source found would make the guard pass vacuously.
      if Seen = 0 then
         Report ("Check_Job_Layer found no Files.Jobs source under " & Root & "/src");
      end if;
   end Check_Job_Layer;
