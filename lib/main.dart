import 'dart:async';

import 'package:flutter/material.dart';
import 'package:f2048/grid-properties.dart';
import 'package:f2048/tile.dart';

void main() {
  runApp(MaterialApp(
    title: '2048',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    home: TwentyFortyEight(),
  ));
}

class TwentyFortyEight extends StatefulWidget {
  @override
  TwentyFortyEightState createState() => TwentyFortyEightState();
}

class TwentyFortyEightState extends State<TwentyFortyEight>
    with SingleTickerProviderStateMixin {
  AnimationController controller;
  int currentStepIndex = 0;
  int undoCount = 0;
  List<List<List<Tile>>> gridStatus = [];
  List<List<Tile>> grid =
      List.generate(4, (y) => List.generate(4, (x) => Tile(x, y, 0)));
  List<Tile> toAdd = [];

  Iterable<Tile> get gridTiles => grid.expand((e) => e);
  Iterable<Tile> get allTiles => [gridTiles, toAdd].expand((e) => e);
  List<List<Tile>> get gridCols =>
      List.generate(4, (x) => List.generate(4, (y) => grid[y][x]));
  List<List<Tile>> get lastgridCols => List.generate(
      4, (x) => List.generate(4, (y) => gridStatus[currentStepIndex][y][x]));

  Timer aiTimer;
  bool isUndo = false;
  String direction;

  @override
  void initState() {
    super.initState();

    controller =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          toAdd.forEach((e) => grid[e.y][e.x].value = e.value);
          gridTiles.forEach((t) => t.resetAnimations());
          toAdd.clear();
        });
      }
    });
    undoCount = 0;

    setupNewGame();
  }

  @override
  Widget build(BuildContext context) {
    double contentPadding = 16;
    double borderSize = 4;
    double gridSize = MediaQuery.of(context).size.width - contentPadding * 2;
    double tileSize = (gridSize - borderSize * 2) / 4;
    List<Widget> stackItems = [];
    stackItems.addAll(gridTiles.map((t) => TileWidget(
        x: tileSize * t.x,
        y: tileSize * t.y,
        containerSize: tileSize,
        size: tileSize - borderSize * 2,
        color: lightBrown)));
    stackItems.addAll(allTiles.map((tile) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) => tile.animatedValue.value == 0
            ? SizedBox()
            : TileWidget(
                x: tileSize * tile.animatedX.value,
                y: tileSize * tile.animatedY.value,
                containerSize: tileSize,
                size: (tileSize - borderSize * 2) * tile.size.value,
                color: numTileColor[tile.animatedValue.value],
                child: Center(child: TileNumber(tile.animatedValue.value))))));

    return Scaffold(
      backgroundColor: tan,
      body: Padding(
        padding: EdgeInsets.all(contentPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                undoCount < 25
                    ? Text(
                        '$undoCount',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 25,
                            fontWeight: FontWeight.w700),
                      )
                    : Text(
                        'Undo is limited!',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 25,
                            fontWeight: FontWeight.w700),
                      ),
                SizedBox(
                  width: 50,
                ),
                undoCount < 25 ? UndoButton(onPressed: undoGame) : Container(),
              ],
            ),
            Swiper(
              up: () => merge(mergeUp),
              down: () => merge(mergeDown),
              left: () => merge(mergeLeft),
              right: () => merge(mergeRight),
              child: Container(
                height: gridSize,
                width: gridSize,
                padding: EdgeInsets.all(borderSize),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cornerRadius),
                    color: darkBrown),
                child: Stack(
                  children: stackItems,
                ),
              ),
            ),
            RestartButton(onPressed: setupNewGame)
          ],
        ),
      ),
    );
  }

  void merge(bool Function() mergeFn) {
    setState(() {
      if (mergeFn()) {
        addNewTiles([2]);
        controller.forward(from: 0);
      }
    });
  }

  List<List<Tile>> copyGrid(grid) {
    List<List<Tile>> newGrid = new List<List<Tile>>();
    for (int i = 0; i < 4; i++) {
      List<Tile> row = new List<Tile>();
      for (int j = 0; j < 4; j++) {
        row.add(new Tile(grid[i][j].x, grid[i][j].y, grid[i][j].value));
      }
      newGrid.add(row);
    }
    return newGrid;
  }

  bool mergeLeft() {
    addGridStatus(copyGrid(grid));
    setState(() {
      direction = "Left";
    });
    return grid.map((e) => mergeTiles(e)).toList().any((e) => e);
  }

  bool mergeRight() {
    addGridStatus(copyGrid(grid));
    setState(() {
      direction = "Right";
    });
    return grid
        .map((e) => mergeTiles(e.reversed.toList()))
        .toList()
        .any((e) => e);
  }

  bool mergeUp() {
    addGridStatus(copyGrid(grid));
    setState(() {
      direction = "Up";
    });
    return gridCols.map((e) => mergeTiles(e)).toList().any((e) => e);
  }

  bool mergeDown() {
    addGridStatus(copyGrid(grid));
    setState(() {
      direction = "Down";
    });
    return gridCols
        .map((e) => mergeTiles(e.reversed.toList()))
        .toList()
        .any((e) => e);
  }

  void addGridStatus(List<List<Tile>> item) {
    if (gridStatus.length < 25) {
      gridStatus.add(item);
      currentStepIndex++;
    }
  }

  bool mergeTiles(List<Tile> tiles) {
    bool didChange = false;
    for (int i = 0; i < tiles.length; i++) {
      for (int j = i; j < tiles.length; j++) {
        if (tiles[j].value != 0) {
          Tile mergeTile = tiles
              .skip(j + 1)
              .firstWhere((t) => t.value != 0, orElse: () => null);
          if (mergeTile != null && mergeTile.value != tiles[j].value) {
            mergeTile = null;
          }
          if (i != j || mergeTile != null) {
            didChange = true;
            int resultValue = tiles[j].value;
            tiles[j].moveTo(controller, tiles[i].x, tiles[i].y);
            if (mergeTile != null) {
              resultValue += mergeTile.value;
              mergeTile.moveTo(controller, tiles[i].x, tiles[i].y);
              mergeTile.bounce(controller);
              mergeTile.changeNumber(controller, resultValue);
              mergeTile.value = 0;
              tiles[j].changeNumber(controller, 0);
            }
            tiles[j].value = 0;
            tiles[i].value = resultValue;
          }
          break;
        }
      }
    }
    return didChange;
  }

  void undoAnimation(List<Tile> tiles) {
    for (int i = 0; i < tiles.length; i++) {
      List<Tile> lastTiles = lastgridCols.asMap()[i];
      for (int j = 1; j < tiles.length; j++) {
        if (tiles[i].value != 0) {
          Tile unMergeTile = tiles
              .skip(j + 1)
              .firstWhere((t) => t.value != 0, orElse: () => null);
          if (tiles[i].value == lastTiles[j].value) {
            tiles[i].moveTo(controller, 2, 3);
            tiles[i].bounce(controller);
            break;
          } else if (tiles[i].value / 2 == lastTiles[j].value) {
            tiles[i].moveTo(controller, 3, 1);
            int result = tiles[i].value ~/ 2;
            lastTiles[j].changeNumber(controller, result);
            break;
          }
        }
      }
    }
  }

  void addNewTiles(List<int> values) {
    List<Tile> empty = gridTiles.where((t) => t.value == 0).toList();
    empty.shuffle();
    for (int i = 0; i < values.length; i++) {
      toAdd.add(Tile(empty[i].x, empty[i].y, values[i])..appear(controller));
    }
  }

  void setupNewGame() {
    setState(() {
      gridTiles.forEach((t) {
        t.value = 0;
        t.resetAnimations();
      });
      toAdd.clear();
      currentStepIndex = 0;
      undoCount = 0;
      gridStatus = [];
      addNewTiles([2, 2]);
      controller.forward(from: 0);
    });
  }

  void undoGame() {
    setState(() {
      if (currentStepIndex > 0) {
        currentStepIndex--;
        undoCount++;
        // if (direction == "Left") {
        //   grid.map((e) => undoAnimation(e.reversed.toList())).toList();
        // } else if (direction == "Right") {
        //   grid.map((e) => undoAnimation(e.toList())).toList();
        // } else if (direction == "Up") {
        //   gridCols.map((e) => undoAnimation(e.reversed.toList())).toList();
        // } else {
        //   gridCols.map((e) => undoAnimation(e.toList())).toList();
        // }

        grid = gridStatus[currentStepIndex];
        gridStatus.removeLast();
      }
      controller.forward(from: 0);
    });
  }
}
