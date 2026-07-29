separate (Files.File_System)
   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result
   is
      Result : Drop_Import_Result :=
        (Success   => False,
         Plans     => Drop_Import_Plan_Vectors.Empty_Vector,
         Error_Key => Null_Unbounded_String);
      --  Destinations already assigned earlier in this batch. They do not yet
      --  exist on disk, so without tracking them two sources sharing a simple
      --  name (from different directories) would resolve to the same target and
      --  the second would silently overwrite the first.
      Claimed : Files.Types.String_Vectors.Vector;

      function Image_No_Space (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Image_No_Space;

      function Extension_Start (Name : String) return Natural is
      begin
         for Index in reverse Name'Range loop
            if Name (Index) = '.' and then Index > Name'First then
               return Index;
            end if;
         end loop;
         return 0;
      end Extension_Start;

      function Is_Claimed (Path : String) return Boolean is
      begin
         for Existing of Claimed loop
            if To_String (Existing) = Path then
               return True;
            end if;
         end loop;
         return False;
      end Is_Claimed;

      function Available_Destination (Leaf : String) return String is
         Dot       : constant Natural := Extension_Start (Leaf);
         Stem      : constant String :=
           (if Dot = 0 then Leaf else Leaf (Leaf'First .. Dot - 1));
         Extension : constant String :=
           (if Dot = 0 then "" else Leaf (Dot .. Leaf'Last));
         Counter   : Positive := 2;
         Candidate : Unbounded_String := To_Unbounded_String (Leaf);
         Full      : Unbounded_String :=
           To_Unbounded_String (Join_Path (Destination_Directory, To_String (Candidate)));
      begin
         while Ada.Directories.Exists (To_String (Full)) or else Is_Claimed (To_String (Full)) loop
            Candidate := To_Unbounded_String (Stem & " " & Image_No_Space (Counter) & Extension);
            Full := To_Unbounded_String (Join_Path (Destination_Directory, To_String (Candidate)));
            exit when Counter = Positive'Last;
            Counter := Counter + 1;
         end loop;
         return To_String (Full);
      end Available_Destination;

      --  True when Inner is Outer itself or a descendant of Outer (normalized).
      function Is_Within_Tree (Inner : String; Outer : String) return Boolean is
         I : constant String := Ada.Directories.Full_Name (Inner);
         O : constant String := Ada.Directories.Full_Name (Outer);
      begin
         --  The boundary is whichever separator the host writes. This accepted
         --  only '/', and Full_Name spells a Windows path with '\', so no
         --  directory was ever inside its own tree there -- and dropping a folder
         --  into its own subfolder, which this exists to refuse, was allowed
         --  straight through into an unbounded recursive copy.
         return I = O
           or else (I'Length > O'Length
                    and then I (I'First .. I'First + O'Length - 1) = O
                    and then (I (I'First + O'Length) = '/'
                              or else I (I'First + O'Length) = '\'));
      end Is_Within_Tree;
   begin
      if not Files.Fs.Directory_Exists (Destination_Directory)
      then
         Result.Error_Key := To_Unbounded_String ("error.drop.invalid_destination");
         return Result;
      end if;

      for Source of Source_Paths loop
         declare
            Source_Text : constant String := To_String (Source);
            Leaf        : Unbounded_String;
            Plan        : Drop_Import_Plan;
         begin
            Plan.Source_Path := Source;
            Plan.Mode := Mode;
            if not Ada.Directories.Exists (Source_Text) then
               Plan.Valid := False;
               Plan.Error_Key := To_Unbounded_String ("error.drop.invalid_source");
               Result.Plans.Append (Plan);
               Result.Error_Key := Plan.Error_Key;
            else
               Leaf := To_Unbounded_String (Ada.Directories.Simple_Name (Source_Text));
               if not Valid_Leaf_Name (To_String (Leaf)) then
                  Plan.Valid := False;
                  Plan.Error_Key := To_Unbounded_String ("error.name.invalid");
                  Result.Error_Key := Plan.Error_Key;
               elsif Is_Within_Tree (Destination_Directory, Source_Text) then
                  --  Refuse to copy or move a directory into itself or one of
                  --  its own descendants; Execute_Drop_Import's recursive copy
                  --  would otherwise recurse without bound.
                  Plan.Valid := False;
                  Plan.Error_Key := To_Unbounded_String ("error.drop.into_self");
                  Result.Error_Key := Plan.Error_Key;
               else
                  Plan.Valid := True;
                  if Mode = Drop_Move
                    and then Ada.Directories.Full_Name
                               (Ada.Directories.Containing_Directory (Source_Text))
                             = Ada.Directories.Full_Name (Destination_Directory)
                  then
                     --  Moving an item into the directory it already lives in is
                     --  a no-op; keep its own path so Execute_Drop_Import skips
                     --  it instead of creating a numbered duplicate. (A copy
                     --  into the same directory still makes a numbered copy.)
                     Plan.Destination_Path := Source;
                  else
                     Plan.Destination_Path := To_Unbounded_String (Available_Destination (To_String (Leaf)));
                  end if;
                  Claimed.Append (Plan.Destination_Path);
                  Plan.Error_Key := Null_Unbounded_String;
               end if;
               Result.Plans.Append (Plan);
            end if;
         exception
            when others =>
               Result.Plans.Append
                 (Drop_Import_Plan'
                    (Source_Path      => Source,
                     Destination_Path => Null_Unbounded_String,
                     Mode             => Mode,
                     Valid            => False,
                     Error_Key        => To_Unbounded_String ("error.drop.failed")));
               Result.Error_Key := To_Unbounded_String ("error.drop.failed");
         end;
      end loop;

      Result.Success := Length (Result.Error_Key) = 0;
      return Result;
   end Plan_Drop_Import;
