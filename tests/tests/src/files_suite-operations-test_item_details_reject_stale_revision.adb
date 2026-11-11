with Files.Extra_Info;
with Files.Extra_Info_Reader;
separate (Files_Suite.Operations)
   procedure Test_Item_Details_Reject_Stale_Revision (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Text     : constant String := Join (Root, "notes.txt");
      Other    : constant String := Join (Root, "other.txt");
      Owner    : constant Files.Extra_Info_Reader.Requester := 403;
      Witness  : constant Files.Extra_Info_Reader.Requester := 404;
      Extra    : Files.Extra_Info.Info;
      Ready    : Boolean;
      Asked    : Boolean;

      function Item_Named (Name : String) return Files.Items.Directory_Item is
         Load : constant Files.File_System.Directory_Load_Result := Files.File_System.Load_Directory (Root, Settings);
      begin
         for Item of Load.Items loop
            if To_String (Item.Name) = Name then
               return Item;
            end if;
         end loop;
         Assert (False, Name & " is listed");
         return Load.Items.First_Element;
      end Item_Named;

      --  Poll Who's request of Item until it is read.
      procedure Await (Who : Files.Extra_Info_Reader.Requester; Item : Files.Items.Directory_Item) is
      begin
         for Attempt in Files_Suite.Support.Polling loop
            Files.Extra_Info_Reader.Take (Who, Item, False, Extra, Ready, Asked);
            Assert (Asked, "a request stays asked until it is read");
            exit when Ready;
         end loop;
         Assert (Ready, "the reader answers");
      end Await;
   begin
      Reset_Root;
      Write_Binary_File (Text, "one" & ASCII.LF & "two" & ASCII.LF & "three" & ASCII.LF);
      Write_File (Other, "x");
      declare
         Old_Item : constant Files.Items.Directory_Item := Item_Named ("notes.txt");
         Witness_Item : constant Files.Items.Directory_Item := Item_Named ("other.txt");
      begin
         Files.Extra_Info_Reader.Request (Owner, Old_Item, False);
         --  One worker serves the oldest request first: once a later request
         --  is read, the first one has been read too.
         Files.Extra_Info_Reader.Request (Witness, Witness_Item, False);
         Await (Witness, Witness_Item);

         --  The file is rewritten and a refresh relists it.
         Write_Binary_File
           (Text, "1" & ASCII.LF & "2" & ASCII.LF & "3" & ASCII.LF & "4" & ASCII.LF & "5" & ASCII.LF & "6");
         declare
            New_Item : constant Files.Items.Directory_Item := Item_Named ("notes.txt");
         begin
            Files.Extra_Info_Reader.Take (Owner, New_Item, False, Extra, Ready, Asked);
            Assert (not Ready, "details read before the file changed are not handed to its new listing");
            Assert (not Asked, "the new listing must be asked for afresh");
            --  The old read was finished all along, for the old listing only.
            Files.Extra_Info_Reader.Take (Owner, Old_Item, False, Extra, Ready, Asked);
            Assert (Ready, "the old read is kept for the listing it was made for");
            Files_Suite.Support.Assert_Equal (Extra.Count, 3, "the old read counted the old file");

            Files.Extra_Info_Reader.Request (Owner, New_Item, False);
            Await (Owner, New_Item);
            Files_Suite.Support.Assert_Equal (Extra.Count, 6, "the new listing gets the new file's details");
         end;
      end;
   end Test_Item_Details_Reject_Stale_Revision;
