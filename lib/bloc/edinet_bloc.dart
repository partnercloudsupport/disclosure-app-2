import 'dart:async';

import 'package:bloc_provider/bloc_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:disclosure_app_fl/bloc/bloc.dart';
import 'package:disclosure_app_fl/models/company.dart';
import 'package:disclosure_app_fl/models/edinet.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

final dateFormatter = DateFormat("yyyy-MM-dd");

class EdinetBloc extends Bloc {
  final path = 'edinets';

  final _edinet$ = BehaviorSubject<List<Edinet>>();
  // final _filter$ = BehaviorSubject<String>(seedValue: '');

  ValueObservable<List<Edinet>> get edinet$ => _edinet$.stream;
  // ValueObservable<String> get filter$ => _filter$;
  // Sink<String> get filterController => _filter$.sink;

  EdinetBloc(AppBloc bloc) {
    final _edinets =
        bloc.user$.switchMap((_) => bloc.edinetDate$).switchMap((date) {
      print("***date*** $date");
      final start = dateFormatter.format(date);
      final end = dateFormatter.format(date.add(Duration(days: 1)));
      return Observable(Firestore.instance
              .collection(path)
              .where('seq', isGreaterThanOrEqualTo: start)
              .where('seq', isLessThan: end)
              .orderBy('seq', descending: true)
              .snapshots())
          .startWith(null);
    }).map((doc) {
      return doc?.documents;
    });

    final _mappedEdinets = Observable.combineLatest2<
        List<DocumentSnapshot>,
        Map<String, Company>,
        Iterable<Edinet>>(_edinets, bloc.companyMap$, (edinets, companies) {
      if (edinets == null) {
        return null;
      }
      return edinets.map((snapshot) {
        final edinet = Edinet.fromDocumentSnapshot(snapshot);
        edinet.fillCompanyName(companies);
        return edinet;
      });
    });

    final _favorite$ =
        Observable.combineLatest2<List<Company>, bool, List<Company>>(
            bloc.favoritesWithName$, bloc.edinetShowOnlyFavorite$,
            (_favorites, _favoriteOnly) {
      if (_favoriteOnly == false) {
        return [];
      }
      return _favorites;
    });

    Observable.combineLatest3<Iterable<Edinet>, String, List<Company>,
            List<Edinet>>(_mappedEdinets, bloc.edinetFilter$, _favorite$,
        (edinets, filter, favorites) {
      if (edinets == null) {
        return null;
      }
      return edinets.where((edinet) {
        if (filter == null || filter == '') {
          return true;
        }
        return edinet.docType == filter;
      }).where((edinet) {
        if (favorites.length == 0) {
          return true;
        }
        return Set.of(favorites).intersection(Set.of(edinet.companies)).length >
            0;
      }).toList();
    }).pipe(_edinet$);
  }

  @override
  void dispose() {
    _edinet$.close();
    // _filter$.close();
  }
}
