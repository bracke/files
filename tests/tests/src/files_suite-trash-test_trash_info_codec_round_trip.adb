with Files.File_System.Trash_Info_Codec;
separate (Files_Suite.Trash)
   procedure Test_Trash_Info_Codec_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Files.File_System.Trash_Info_Codec;

      --  Every byte value, so no byte is lost or changed on the way.
      function All_Bytes return String is
         Result : String (1 .. 256);
      begin
         for Code in 0 .. 255 loop
            Result (Code + 1) := Character'Val (Code);
         end loop;
         return Result;
      end All_Bytes;
   begin
      Files_Suite.Support.Assert_Equal (Encode ("/home/a b/x%y"), "/home/a%20b/x%25y", "spaces and % are escaped");
      Files_Suite.Support.Assert_Equal (Encode ("/A-z_0.9~"), "/A-z_0.9~", "unreserved bytes and / stay");
      Files_Suite.Support.Assert_Equal (Encode ("/" & Character'Val (16#C3#) & Character'Val (16#A6#)),
                                        "/%C3%A6", "UTF-8 bytes are escaped as upper-case hex");
      Files_Suite.Support.Assert_Equal (Decode ("/%c3%a6"), "/" & Character'Val (16#C3#) & Character'Val (16#A6#),
                                        "lower-case hex decodes");
      Files_Suite.Support.Assert_Equal (Decode ("/a%2"), "/a%2", "a truncated escape is kept");
      Files_Suite.Support.Assert_Equal (Decode ("/a%zz"), "/a%zz", "a non-hex escape is kept");
      Files_Suite.Support.Assert_Equal (Decode (Encode (All_Bytes)), All_Bytes, "every byte round-trips");
      Files_Suite.Support.Assert_Equal (Decode (Encode ("")), "", "the empty path round-trips");
   end Test_Trash_Info_Codec_Round_Trip;
