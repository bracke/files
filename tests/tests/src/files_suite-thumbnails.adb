with Files.File_System.Thumbnails;
with Files.Items;
with Files.File_Identities.Testing;
with Files.Process_Jobs;
with Files.Job_Records;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Directories;
with Ada.Environment_Variables;
with Interfaces;
with Files.Quick_Look;
with Ada.Streams;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Project_Tools.Files;
with GNAT.OS_Lib;
with Textrender.Fonts;
with Zlib;
with Hostkit.Host;
with Files.Commands;
with Files.Controller;
with Files.File_System;
with Files.Model;
with Files.Model.Selection;
with Files.Operations;
with Hostkit.Fs;
with Hostkit.Metadata;
with Files.Rendering;
with Guikit.Vulkan;
with Files.Settings;
with Guikit.Shared_Bytes;
with Files.Types;
with Files_Suite.Support;
with Files_Suite.Operations_Support;

package body Files_Suite.Thumbnails is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Hostkit.Host.Kind;
   use type Files.Commands.Command_Id;
   use type Files.File_System.Thumbnails.Thumbnail_Status;
   use type Files.Operations.Operation_Status;
   use type Interfaces.Unsigned_8;
   use type Textrender.Fonts.Load_Result;
   use type Files.Types.View_Mode;
   use Files_Suite.Support;
   use Files_Suite.Operations_Support;

   type Thumbnails_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Thumbnails_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Thumbnails_Test_Case);

   procedure Test_Navigation_Defers_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Plain_Listing_Makes_No_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Netpbm_Fields (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Generation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Png_Thumbnail_Decoding (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Directory_Load_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Cache_Entries (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Command_Rendering (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Cache_Is_Per_User (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Cache_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Cache_Prune_Past_Cap (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Listing_Counts_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Decode_Emoji_Png_From_Font (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Image_Header_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Oversized_Image_File_Refused (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Cut_Text (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Decodes_Off_Thread (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Thumbnail_Transport_Budget (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Explicit_Thumbnail_Survives_The_Listing (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Thumbnails_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files thumbnails and previews");
   end Name;

   overriding procedure Register_Tests (T : in out Thumbnails_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Generation'Access, "thumbnail generation writes safe owner-only cache artifacts");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Png_Thumbnail_Decoding'Access, "PNG thumbnails decode, bound inflate and composite transparency");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Directory_Load_Thumbnails'Access, "the generating listing auto-generates image thumbnails");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Cache_Entries'Access, "thumbnail cache entries are validated when loaded");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Command_Rendering'Access, "thumbnail command output reaches the large-icons atlas only");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Cache_Is_Per_User'Access,
         "the thumbnail cache lands in this host's user cache, not the browsed folder");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Cache_Is_Bounded'Access,
         "the thumbnail cache is pruned to its budget, oldest first");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Cache_Prune_Past_Cap'Access,
         "a thumbnail cache holding more than the prune cap is still pruned, back under the cap and the budget");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Listing_Counts_Thumbnails'Access,
         "a thumbnail cache listing counts only thumbnails against its cap");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Decodes_Off_Thread'Access,
         "Quick Look decodes its image off the UI thread and drops what is no longer previewed");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Thumbnail_Transport_Budget'Access, "a refresh carries thumbnails only up to its pixel budget");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Image_Header_Bytes'Access,
         "image headers: big-endian sizes clamp, and a PNG needs IHDR first");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Oversized_Image_File_Refused'Access,
         "an image file whose header declares more than the source bounds is refused before decoding");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Cut_Text'Access,
         "a text preview cut at the byte cap is truncated and ends on whole UTF-8 text");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Decode_Emoji_Png_From_Font'Access,
         "a real colour emoji picture decodes out of a real font");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Explicit_Thumbnail_Survives_The_Listing'Access,
         "a thumbnail generated for a non-image item is still shown when the directory is listed");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Navigation_Defers_Thumbnails'Access,
         "opening a folder never waits on new thumbnails: a background listing makes them");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Plain_Listing_Makes_No_Thumbnails'Access,
         "a plain directory listing decodes no image and writes no thumbnail cache file");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Netpbm_Fields'Access,
         "the Netpbm reader splits fields, refuses bad numbers and scales samples");
   end Register_Tests;

   procedure Test_Thumbnail_Generation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Png_Thumbnail_Decoding (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Directory_Load_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Cache_Entries (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Command_Rendering (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Thumbnails are a regenerable per-user cache and belong in the user's cache
   --  area. The resolver consulted only XDG_CACHE_HOME and HOME, and on Windows
   --  neither is normally set, so it fell through to its last resort: a hidden
   --  .files-thumbnails directory written into whichever folder was being
   --  browsed -- in the user's own data, and listed back to them. The guard that
   --  matters on every host is the last assertion: given somewhere to put a
   --  cache, it never picks the browsed folder.
   --  The cache used to grow without limit: nothing ever deleted a thumbnail,
   --  so it kept one file per image ever browsed, plus every orphan whose source
   --  had since been renamed or deleted.
   --  The permission column takes the execute bit from the item's Kind instead
   --  of asking the host a second time, which is only sound while the
   --  classifiers keep implying it. This is what notices if that stops being
   --  true: without it the column would quietly disagree with the filesystem.
   --  The listing reads the thumbnail cache's own directory once instead of
   --  stat-ing a cache path per entry. The tempting cheaper version -- ask "is
   --  this an image?" first and skip the lookup when it is not -- is wrong, and
   --  this is the case that makes it wrong: Generate_Selected_Thumbnails has no
   --  image gate, so the thumbnail command will happily produce one for a text
   --  file, and the listing has to keep showing it. Reading what is actually in
   --  the cache keeps that true; guessing from the filetype would not.
   procedure Test_Explicit_Thumbnail_Survives_The_Listing (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   --  Decode a real colour emoji picture out of a real font.
   --
   --  Textrender reads where the picture is and hands out the bytes; this is the
   --  other side of that seam, and until it worked the colour glyph path had only
   --  ever been driven by a stub returning a known pattern. The bytes here are
   --  whatever Noto Color Emoji actually contains.
   --
   --  Skipped when the font is not installed, so a missing font is not a failure.
   procedure Test_Decode_Emoji_Png_From_Font (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Image_Header_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Oversized_Image_File_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Quick_Look_Cut_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Quick_Look_Decodes_Off_Thread (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Transport_Budget (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Cache_Is_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Cache_Prune_Past_Cap (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Listing_Counts_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Thumbnail_Cache_Is_Per_User (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Navigation_Defers_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Plain_Listing_Makes_No_Thumbnails (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Netpbm_Fields (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Thumbnails_Test_Case));
      return Result;
   end Suite;

end Files_Suite.Thumbnails;
