separate (Files_Suite.Recovery)
   --  An identity token is written one way and read one way: what Image
   --  writes, Parse reads back, and what it did not write it refuses.
   procedure Test_Identity_Token_Round_Trips (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path : constant String := Join (Root, "identified");
      Item : Hostkit.Metadata.Entry_Identity;
      --  Not four decimal fields.
      Refused : constant array (1 .. 4) of Unbounded_String :=
        [To_Unbounded_String (""), To_Unbounded_String (" 1 2 3"),
         To_Unbounded_String (" 1 2 3 4 5"), To_Unbounded_String (" 1 2 x 4")];
   begin
      Reset_Root;
      Write_Binary_File (Path, "bytes");
      declare
         Token : constant String := Files.File_Identities.Token (Path);
      begin
         if Token = "" then
            Files_Suite.Support.Skip ("Test_Identity_Token_Round_Trips", "the host gives no identity");
            return;
         end if;
         Assert (Files.File_Identities.Parse (Token, Item) and then Item.Available, "a token parses");
         Files_Suite.Support.Assert_Equal (Files.File_Identities.Image (Item), Token, "and images back to itself");
      end;
      Files_Suite.Support.Assert_Equal
        (Files.File_Identities.Image ((others => <>)), "", "an unavailable identity has no token");
      for Text of Refused loop
         Assert (not Files.File_Identities.Parse (To_String (Text), Item) and then not Item.Available,
                 "a token that is not four numbers is refused, leaving no identity: [" & To_String (Text) & "]");
      end loop;
   end Test_Identity_Token_Round_Trips;
