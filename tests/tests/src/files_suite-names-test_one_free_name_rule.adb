with Files.Operations.History.Testing;
with Files.File_Types;
with Files.Model.Jobs;
with Files.Operations.Archives;
with Files.Operations.History;
with Files_Suite.Listings;
with Files.Leaf_Names;
with Files.Operation_Results;
with Files.Name_Parts;

separate (Files_Suite.Names)
   --  Every new name -- a copy, a link, an archive, a paste, an untitled
   --  file, a trash payload -- is found by one search (Leaf_Names.First_Free)
   --  with one attempt bound, its marker cut to fit; a plain folder's dots are
   --  part of its name, a package's extension is not; an extension mapping
   --  folds case in every script; a hidden extension is found by the one rule.
   procedure Test_One_Free_Name_Rule (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package LN renames Files.Leaf_Names;
      Default  : constant Hostkit.Fs.Leaf_Name_Limit := LN.Default_Limit;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Step     : Files.Operation_Results.Operation_Result;
      Load     : Files.File_System.Directory_Load_Result;

      function None (Leaf : String) return Boolean is (Leaf = "");
      function All_Taken (Leaf : String) return Boolean is (Leaf /= "");
      function First_Two (Leaf : String) return Boolean is (Leaf in "notes.txt" | "notes 2.txt");
      function Only_Bare (Leaf : String) return Boolean is (Leaf = "v1.2");

      function Listed (Name : String) return Boolean is
        (for some Item of Load.Items => To_String (Item.Name) = Name);
   begin
      --  The markers each operation is told apart by.
      Files_Suite.Support.Assert_Equal (LN.Counted_Marker ("copy", 1), " (copy)", "the first copy marker");
      Files_Suite.Support.Assert_Equal (LN.Counted_Marker ("copy", 3), " (copy 3)", "a counted copy marker");
      Files_Suite.Support.Assert_Equal (LN.Numbered_Marker (0) & LN.Numbered_Marker (2), " (2)", "an archive's");
      Files_Suite.Support.Assert_Equal (LN.Spaced_Number (1) & LN.Spaced_Number (3), " 3", "a paste's");
      Files_Suite.Support.Assert_Equal (LN.Dotted_Number (1) & LN.Dotted_Number (4), ".4", "a trash payload's");

      --  One search: the first free name, "" when the bound is reached.
      Files_Suite.Support.Assert_Equal
        (LN.First_Free ("notes", "txt", LN.Spaced_Number'Access, First_Two'Access, Default), "notes 3.txt",
         "the first free numbered name");
      Files_Suite.Support.Assert_Equal
        (LN.First_Free ("notes", "txt", LN.Spaced_Number'Access, None'Access, Default), "notes.txt",
         "a free bare name is kept");
      Files_Suite.Support.Assert_Equal
        (LN.First_Free ("notes", "txt", LN.Spaced_Number'Access, All_Taken'Access, Default), "",
         "no name once every attempt is taken");

      --  A marker after the whole name (a trash payload) cuts the stem, and
      --  keeps the extension and the marker.
      declare
         Long : constant String := [1 .. 250 => 'n'];
         Name : constant String := LN.Candidate (Long & ".txt", "", ".12", Default, LN.After_Name);
      begin
         Assert (Name'Length = 255, "a payload name fits:" & Name'Length'Image);
         Files_Suite.Support.Assert_Equal
           (Name (Name'Last - 6 .. Name'Last), ".txt.12", "the extension and the counter are kept, in order");
      end;

      --  A plain folder's dots are its name's; a package's extension names it.
      Files_Suite.Support.Assert_Equal (Files.Name_Parts.Name_Stem ("v1.2", True), "v1.2", "a folder is all stem");
      Files_Suite.Support.Assert_Equal (Files.Name_Parts.Name_Extension ("v1.2", True), "", "with no extension");
      Files_Suite.Support.Assert_Equal (Files.Name_Parts.Name_Stem ("Mail.app", True), "Mail",
                                        "a package keeps its split");
      Files_Suite.Support.Assert_Equal (Files.Name_Parts.Name_Stem ("v1.2", False), "v1", "a file splits");
      Files_Suite.Support.Assert_Equal
        (Files.Paste.First_Free_Name ("v1.2", Only_Bare'Access, Is_Directory => True), "v1.2 2",
         "a numbered folder keeps its dots");

      --  An extension mapping folds case in every script.
      Files_Suite.Support.Assert_Equal
        (Files.File_Types.Normalize_Extension
           ("." & Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("ДОК")),
         Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("док"),
         "a Cyrillic extension folds to lower case");

      --  On disk: an untitled file and a folder's copy and archive.
      Reset_Root;
      Write_Binary_File (Join (Root, "untitled.txt"), "x");
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Next_Untitled_Name (Root), "untitled 2.txt", "the next untitled name is numbered");
      Ada.Directories.Create_Directory (Join (Root, "v1.2"));
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Operations.History.Testing.Clear_Undo (Model);
      Files.Model.Jobs.Set_Background_Transfers (Model, False);
      Select_Name (Model, "v1.2");
      Step := Operation_Commands.Duplicate_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operation_Results.Operation_Success, "the folder is duplicated");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Assert (Listed ("v1.2 (copy)"), "a folder's copy keeps its dots in its name");
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "v1.2");
      Step := Operation_Commands.Compress_Selected (Model, Settings, Files.Operations.Archives.Zip_Archive);
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operation_Results.Operation_Success, "the folder is compressed");
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Assert (Listed ("v1.2.zip"), "a folder's archive is named for all of its name");
   end Test_One_Free_Name_Rule;
