//------------------------------------------------------------------------------
// emHmiDemoCone.cpp
//
// Copyright (C) 2012,2014,2024 Oliver Hamann.
//
// Homepage: http://eaglemode.sourceforge.net/
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License version 3 as published by the
// Free Software Foundation.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License version 3 for
// more details.
//
// You should have received a copy of the GNU General Public License version 3
// along with this program. If not, see <http://www.gnu.org/licenses/>.
//------------------------------------------------------------------------------

#include <emHmiDemo/emHmiDemoCone.h>


emHmiDemoCone::emHmiDemoCone(
	ParentArg parent, const emString & name,
	int rx, int ry, int rw, int rh, int state,
	emColor color
)
	: emHmiDemoPiece(parent,name,rx,ry,rw,rh,"18",color),
	State(state),
	LbName(NULL),
	FillIndicator(NULL)
{
	SetFocusable(true);
}


emHmiDemoCone::~emHmiDemoCone()
{
}


void emHmiDemoCone::AutoExpand()
{
	emHmiDemoPiece::AutoExpand();

	LbName=new emLabel(this,"name",GetName());
	emLook look;
	look.SetBgColor(0);
	look.SetFgColor(0x00000099);
	LbName->SetLook(look);

	FillIndicator = new emHmiDemoFillIndicator(this,"fill",0.5);
	FillIndicator->SetFill(State/10.0+0.08);
}


void emHmiDemoCone::AutoShrink()
{
	emHmiDemoPiece::AutoShrink();
	LbName=NULL;
	FillIndicator=NULL;
}


void emHmiDemoCone::LayoutChildren()
{
	if (LbName) LbName->Layout(0.05,0.05,0.4,0.11,GetInnerColor());
	if (FillIndicator) FillIndicator->Layout(0.65,0.07,0.12,0.45,GetInnerColor());
}
