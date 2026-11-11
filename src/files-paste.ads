with Ada.Containers.Vectors;

with Files.Types;

--  Pure, side-effect-free paste/move conflict-resolution core.
--
--  This package models a paste (or cut-and-paste move) as a work-list of
--  destination items and, given a conflict policy plus any per-item overrides
--  and the set of destination paths that already exist, computes the concrete
--  actions to perform: write (create), write-over (replace), skip, or write to a
--  uniquified name (rename). It performs no filesystem access and no rendering;
--  existence is supplied as data (the Existing vector), which makes the whole
--  resolution deterministically unit-testable. Callers detect conflicts, drive
--  the interactive dialog, and execute the resolved actions elsewhere.
package Files.Paste is

   --  Batch-wide conflict policy. Policy_Ask leaves each conflict for the user
   --  to decide (its effective per-item decision stays Decision_Pending); the
   --  *_All policies apply one choice to every remaining conflict at once.
   type Conflict_Policy is
     (Policy_Ask,
      Policy_Replace_All,
      Policy_Skip_All,
      Policy_Rename_All);

   --  A per-item decision. Decision_Pending means "not yet decided"; the
   --  concrete choices mirror the dialog buttons.
   type Item_Decision is
     (Decision_Pending,
      Decision_Replace,
      Decision_Skip,
      Decision_Rename);

   package Item_Decision_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Item_Decision);

   --  One planned destination for a source path. Dest_Dir and Dest_Name give the
   --  desired (un-uniquified) destination; conflicts are detected against that
   --  joined path.
   type Work_Item is record
      Source_Path : Files.Types.UString;
      Dest_Dir    : Files.Types.UString;
      Dest_Name   : Files.Types.UString;
   end record;

   package Work_Item_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Work_Item);

   --  A concrete action for one work item. When Skip is True nothing is copied
   --  or moved. Otherwise the source is written to Dest_Path; Replaced is True
   --  when Dest_Path already existed and must be overwritten (an explicit
   --  Replace choice), and False for a fresh write or a uniquified rename.
   type Resolved_Action is record
      Source_Path : Files.Types.UString;
      Dest_Path   : Files.Types.UString;
      Skip        : Boolean := False;
      Replaced    : Boolean := False;
   end record;

   package Resolved_Action_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Resolved_Action);

   --  Join a destination directory and leaf name into the desired full path.
   --
   --  @param Dir Destination directory.
   --  @param Name Desired leaf name.
   --  @return The desired destination path (Dir and Name joined with the host's
   --  separator, as Hostkit.Fs.Join joins them).
   function Desired_Path
     (Dir  : String;
      Name : String)
      return String;

   --  Index of the first conflicting item after position After whose effective
   --  decision is still Decision_Pending, or 0 when every remaining conflict is
   --  decided (or there are no conflicts).
   --
   --  @param Items Work-list.
   --  @param Policy Batch-wide policy.
   --  @param Overrides Per-item overrides (may be empty; missing entries are Pending).
   --  @param Existing Full destination paths known to exist.
   --  @param After Only items with index greater than After are considered.
   --  @return One-based index of the next unresolved conflict, or 0 when none.
   function Next_Unresolved_Conflict
     (Items     : Work_Item_Vectors.Vector;
      Policy    : Conflict_Policy;
      Overrides : Item_Decision_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector;
      After     : Natural := 0)
      return Natural;

   --  Resolve a whole work-list into concrete actions. Non-conflicting items are
   --  always written (uniquified only to avoid clobbering an earlier action in
   --  the same batch). Conflicting items follow their effective decision:
   --  Replace writes over the destination, Skip does nothing, Rename writes to a
   --  uniquified name that avoids both Existing and names already claimed in this
   --  batch, and an undecided conflict (Policy_Ask with no override) is skipped
   --  as the safe never-clobber default.
   --
   --  @param Items Work-list.
   --  @param Policy Batch-wide policy.
   --  @param Overrides Per-item overrides (may be empty; missing entries are Pending).
   --  @param Existing Full destination paths known to exist.
   --  @param Fold_Names Whether the destination folds case
   --    (Hostkit.Fs.Folds_Name_Case): two items whose names differ only in
   --    case then claim one destination, and the second is renamed; a
   --    replace keeps the existing entry's spelling (the first Existing
   --    path that folds equal), so its original comes back under it.
   --  @param Dos_Names Whether the destination keeps names in UTF-16
   --    (Hostkit.Fs.Uses_Dos_Filename_Rules): a numbered name is then cut to
   --    fit in UTF-16 units rather than bytes (First_Free_Name).
   --  @return One resolved action per work item, in order.
   function Resolve
     (Items     : Work_Item_Vectors.Vector;
      Policy    : Conflict_Policy;
      Overrides : Item_Decision_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector;
      Fold_Names : Boolean := False;
      Dos_Names  : Boolean := False)
      return Resolved_Action_Vectors.Vector;

   --  Name, or the first of "stem 2.ext", "stem 3.ext" ... that Taken says
   --  is free: the one numbering a paste and a drop give a name in use. A
   --  numbered name the destination could not store is cut down to fit
   --  (Files.Leaf_Names): the stem loses whole characters from its end, the
   --  counter and the extension are kept.
   --
   --  @param Name The leaf name wanted.
   --  @param Taken Whether a leaf name is in use.
   --  @param Dos_Rules Whether the destination measures names in UTF-16
   --    units (Hostkit.Fs.Uses_Dos_Filename_Rules) rather than bytes.
   --  @return A leaf name Taken says is free.
   function First_Free_Name
     (Name      : String;
      Taken     : not null access function (Leaf : String) return Boolean;
      Dos_Rules : Boolean := False)
      return String;

end Files.Paste;
