separate (Check_All)
   procedure Check_Clock_Arithmetic is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");
      Time_Names : Name_Sets.Set;

      procedure Refuse (Path, What : String) is
      begin
         Put_Line
           (Standard_Error,
            Path & ": " & What & " can overflow (Time_First is a common start); use Files.Timing.Elapsed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Refuse;

      procedure Check (Path : String) is separate;

      --  Every name declared with a time type: "Name : [aliased] [constant]
      --  Ada.Real_Time.Time" or "... Ada.Calendar.Time".
      procedure Collect (Path : String) is separate;

      procedure For_Each_Source (Visit : not null access procedure (Path : String)) is
      begin
         Ada.Directories.Start_Search
           (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Visit (Ada.Directories.Full_Name (Item));
         end loop;
         Ada.Directories.End_Search (Search);
      end For_Each_Source;
      --  The times a file can name: its own, and those of the specs and
      --  bodies of its unit family (a stem that is a dash-prefix of its own).
      procedure Check_With_Family (Path : String) is
         Stem : constant String := Ada.Directories.Base_Name (Path);

         procedure Collect_If_Family (Other : String) is
            Other_Stem : constant String := Ada.Directories.Base_Name (Other);
         begin
            if Other_Stem = Stem
              or else (Other_Stem'Length < Stem'Length
                       and then Stem (Stem'First .. Stem'First + Other_Stem'Length - 1) = Other_Stem
                       and then Stem (Stem'First + Other_Stem'Length) = '-')
            then
               Collect (Other);
            end if;
         end Collect_If_Family;

         Family_Search : Ada.Directories.Search_Type;
         Family_Item   : Ada.Directories.Directory_Entry_Type;
      begin
         Time_Names.Clear;
         Ada.Directories.Start_Search
           (Family_Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Family_Search) loop
            Ada.Directories.Get_Next_Entry (Family_Search, Family_Item);
            Collect_If_Family (Ada.Directories.Full_Name (Family_Item));
         end loop;
         Ada.Directories.End_Search (Family_Search);
         Check (Path);
      end Check_With_Family;
   begin
      For_Each_Source (Check_With_Family'Access);
   end Check_Clock_Arithmetic;
