separate (Files_Suite.Operations)
   --  A job record carries a user or group id from 2**31 up (an idmapped
   --  mount's, NFS's nobody) unchanged, and the four bytes it writes for an id
   --  are the four a Natural wrote before ids were Account_Id, so a record
   --  written then reads back the same.
   procedure Test_Job_Item_Large_Account_Ids (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Account_Id;
      Path   : constant String := Join (Root, "large-account-ids");
      File   : Ada.Streams.Stream_IO.File_Type;
      Items  : Files.File_System.Item_Vectors.Vector;
      Item   : Files.File_System.Directory_Item;
      Nobody : constant Files.Types.Account_Id := 4_294_967_294;
      Mapped : constant Files.Types.Account_Id := 2**31;
   begin
      Reset_Root;
      Item := Files.File_System.Make_Item (Root, "owned-item", Files.Types.Regular_File_Item);
      Item.Ownership_Available := True;
      Item.Owner_Id := Nobody;
      Item.Group_Id := Mapped;
      Items.Append (Item);
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Files.Job_Records.Write_Items (Ada.Streams.Stream_IO.Stream (File), Items);
      Ada.Streams.Stream_IO.Close (File);

      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      Items := Files.Job_Records.Read_Items (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      Files_Suite.Support.Assert_Equal (Natural (Items.Length), 1, "the record holds the one item");
      Assert (Items.First_Element.Ownership_Available, "the item keeps its ownership");
      Files_Suite.Support.Assert_Equal
        (Items.First_Element.Owner_Id, Nobody, "an owner id above Natural'Last round-trips");
      Files_Suite.Support.Assert_Equal
        (Items.First_Element.Group_Id, Mapped, "a group id of 2**31 round-trips");

      --  An id as the Natural format wrote it reads back as the same id.
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Natural'Output (Ada.Streams.Stream_IO.Stream (File), 1_000);
      Natural'Output (Ada.Streams.Stream_IO.Stream (File), Natural'Last);
      Ada.Streams.Stream_IO.Close (File);
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      Files_Suite.Support.Assert_Equal
        (Files.Types.Account_Id'Input (Ada.Streams.Stream_IO.Stream (File)), 1_000,
         "an id written as a Natural reads back as the same Account_Id");
      Files_Suite.Support.Assert_Equal
        (Files.Types.Account_Id'Input (Ada.Streams.Stream_IO.Stream (File)),
         Files.Types.Account_Id (Natural'Last),
         "the largest Natural id reads back unchanged");
      Assert (Ada.Streams.Stream_IO.End_Of_File (File), "and each took exactly four bytes");
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Job_Item_Large_Account_Ids;
