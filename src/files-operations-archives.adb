with Files.Model.Recent;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Files.IO.Fs_Primitives;
with Files.Jobs.Context;
with Hostkit.Metadata;
with Hostkit;
with Hostkit.Fs;
with Zlib;
with Files.Operations.Support;
with Files.Leaf_Names;
with Ada.Containers;
with Files.Diagnostics;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
with Ada.Unchecked_Deallocation;
with Files.Operations.Undo_Recording;
with Files.Operations.Archives.Writing;
with Files.Model.Selection;
with Files.Undo.History;

package body Files.Operations.Archives is

   use Ada.Strings.Unbounded;
   use type Files.Types.Item_Kind;
   use type Ada.Directories.File_Kind;
   use type Files.Undo.History.Undo_Action_Kind;
   use type Zlib.Status_Code;
   use Files.Operations.Support;
   use Files.Operations.Undo_Recording;

   package Archive_Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   type Text_Array_Access is access Zlib.Text_Array;

   procedure Free_Text_Array is new Ada.Unchecked_Deallocation
     (Zlib.Text_Array, Text_Array_Access);

   function Compress_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Format   : Archive_Format)
      return Operation_Result
   is separate;

   function Extract_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is separate;

end Files.Operations.Archives;
