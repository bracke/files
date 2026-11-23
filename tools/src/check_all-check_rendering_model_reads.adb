separate (Check_All)
   procedure Check_Rendering_Model_Reads is
      --  A frame reads the model and changes none of it; nor does a dispatch
      --  (Files.Interaction), which changes it only through the controller.
      --  Every subprogram in Files.Model or any of its children that takes
      --  the Window_Model "in out" is a mutator; the list is derived from the
      --  specs, so a new child or a new mutator is covered without editing
      --  this check. A dispatch is refused more: any subprogram outside
      --  Files.Controller (and Interaction's own family) that takes the
      --  model "in out" -- an operation, a refresh, an overlay's edit --
      --  changes it past the controller. A leading "Model." is read as
      --  "Files.Model." (a unit of Files may name it so). A
      --  rendering unit names the model in full: a use clause ("use
      --  Files.Model.Selection", "use all type") or a renaming of a model
      --  unit would let a mutator be called by a name this check cannot see,
      --  so those are refused too.
      use Tokens;

      Mutators : Key_Sets.Set;
      --  Every subprogram outside the controller and Interaction that takes
      --  the model "in out", the model's mutators among them.
      Past_Controller : Key_Sets.Set;

      --  Adds Unit.Name to Into for every subprogram in the spec at Path
      --  whose parameter list has a Window_Model "in out".
      procedure Collect (Path : String; Into : in out Key_Sets.Set) is
         Unit : constant String := Unit_Of_File (Path);
      begin
         for Name of Subprograms_With_Parameter
           (Project_Tools.Files.Read_Raw_File (Path), Mode => "in out", Type_Name => "window_model")
         loop
            Into.Include (Unit & "." & To_String (Name));
         end loop;
      end Collect;

      function Starts (Text, Prefix : String) return Boolean is
        (Text'Length >= Prefix'Length and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

      --  Whether Name is a model unit: Files.Model or a child of it.
      function Is_Model (Name : String) return Boolean is
        (Name = "files.model" or else Starts (Name, "files.model."));

      --  The dotted name starting at From, lower case.
      function Name_At (Toks : Token_List; From : Positive) return String is
         Result : Unbounded_String;
      begin
         for Index in From .. Past_Name_Prefix (Toks, From) loop
            Append (Result, (if Toks (Index).Kind = Word then To_String (Toks (Index).Text) else "."));
         end loop;
         return To_String (Result);
      end Name_At;

      --  Every dotted name in the file at Path that is a mutator, and every
      --  use clause or renaming of a model unit; Who says whose file it is.
      procedure Check (Path : String; Who : String; Refused : Key_Sets.Set) is
         Toks : constant Token_List := Tokens_Of (Project_Tools.Files.Read_Raw_File (Path));
         Index : Positive := Toks.First_Index;
      begin
         while Index <= Toks.Last_Index loop
            if Is_Word (Toks (Index), "use") and then Index < Toks.Last_Index then
               declare
                  First : Positive := Index + 1;
               begin
                  --  "use type T" makes only operators visible; "use all
                  --  type T" makes every primitive of T visible, mutators too.
                  if Is_Word (Toks (First), "type") then
                     First := Toks.Last_Index + 1;
                  elsif Is_Word (Toks (First), "all") and then First + 1 <= Toks.Last_Index
                    and then Is_Word (Toks (First + 1), "type")
                  then
                     First := First + 2;
                  end if;
                  if First <= Toks.Last_Index and then Toks (First).Kind = Word
                    and then Is_Model (Name_At (Toks, First))
                  then
                     Report (Path & ": " & Who & " names the model in full, not through ""use "
                             & Name_At (Toks, First) & """");
                  end if;
               end;
               Index := Index + 1;
            elsif Is_Word (Toks (Index), "renames") and then Index < Toks.Last_Index
              and then Toks (Index + 1).Kind = Word
              and then Is_Model (Name_At (Toks, Index + 1))
            then
               Report (Path & ": " & Who & " names the model in full, not through a renaming of "
                       & Name_At (Toks, Index + 1));
               Index := Index + 1;
            elsif (Is_Word (Toks (Index), "files") or else Is_Word (Toks (Index), "model"))
              and then (Index = Toks.First_Index or else not Is_Symbol (Toks (Index - 1), "."))
            then
               declare
                  Name : constant String :=
                    (if Is_Word (Toks (Index), "model") then "files." else "") & Name_At (Toks, Index);
               begin
                  if Refused.Contains (Name) then
                     Report (Path & ": " & Who & " must not change the model (" & Name & ")");
                  end if;
                  Index := Past_Name_Prefix (Toks, Index) + 1;
               end;
            else
               Index := Index + 1;
            end if;
         end loop;
      end Check;
   begin
      for Pattern of String_List'[To_Unbounded_String ("files-model.ads"), To_Unbounded_String ("files-model-*.ads")]
      loop
         for Item of Project_Tools.Files.List_Tree (Root & "/src", To_String (Pattern), Generated_Directories) loop
            Collect (To_String (Item), Mutators);
         end loop;
      end loop;
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ads", Generated_Directories) loop
         declare
            Unit : constant String := Unit_Of_File (To_String (Item));
         begin
            if not (Unit = "files.controller" or else Starts (Unit, "files.controller.")
                    or else Unit = "files.interaction" or else Starts (Unit, "files.interaction."))
            then
               Collect (To_String (Item), Past_Controller);
            end if;
         end;
      end loop;
      --  An empty list would make the guard pass vacuously.
      if Natural (Mutators.Length) < 20 then
         Report ("Check_Rendering_Model_Reads found only" & Natural'Image (Natural (Mutators.Length))
                 & " model mutators; the spec scan is broken");
      end if;
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "files-rendering*.ad?", Generated_Directories) loop
         Check (To_String (Item), "a frame", Mutators);
      end loop;
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "files-interaction*.ad?", Generated_Directories) loop
         Check (To_String (Item), "a dispatch (it goes through Files.Controller)", Past_Controller);
      end loop;
   end Check_Rendering_Model_Reads;
