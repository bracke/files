separate (Check_All)
   procedure Require_Not_Contains_In_Unit
     (Base_Path : String;
      Pattern   : String;
      Message   : String)
   is
      Dir     : constant String := Ada.Directories.Containing_Directory (Base_Path);
      Stem    : constant String := Ada.Directories.Base_Name (Base_Path);
      Ext     : constant String := Ada.Directories.Extension (Base_Path);
      Prefix  : constant String := Stem & "-";
      Suffix  : constant String := ".adb";
      Search  : Ada.Directories.Search_Type;
      Item    : Ada.Directories.Directory_Entry_Type;
      Started : Boolean := False;
   begin
      Require_Not_Contains (Base_Path, Pattern, Message);

      --  Only a body has subunits; a spec (.ads) is covered on its own.
      if Ext /= "adb" then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Dir,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => False,
            Ada.Directories.Special_File  => False]);
      Started := True;
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Name'Length > Prefix'Length + Suffix'Length
              and then Name (Name'First .. Name'First + Prefix'Length - 1) = Prefix
              and then Name (Name'Last - Suffix'Length + 1 .. Name'Last) = Suffix
            then
               Require_Not_Contains
                 (Ada.Directories.Full_Name (Item), Pattern, Message);
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Require_Not_Contains_In_Unit;
