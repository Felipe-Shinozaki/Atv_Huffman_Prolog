% Membros:
% - Enzo Maranho 10436106
% - Felipe Hideki 10438584
% - Gabriel Messora 10438405

% =======================================================
% 1. LEITURA DE ARQUIVO
% =======================================================

% Lê o arquivo e retorna uma lista de caracteres filtrados (apenas letras minúsculas e dígitos)
ler_arquivo(Caminho, Chars) :-
    open(Caminho, read, Stream),
    read_stream(Stream, Chars),
    close(Stream).

read_stream(Stream, Chars) :-
    get_char(Stream, Char),
    ( Char == end_of_file -> Chars = []
    ; processar_char(Char, LowerChar) -> 
        Chars = [LowerChar | Rest],
        read_stream(Stream, Rest)
    ; % Se não for alfanumérico, ignora
      read_stream(Stream, Chars)
    ).

% Aceita apenas letras e dígitos, convertendo para minúsculo
processar_char(Char, LowerChar) :-
    char_type(Char, alnum),
    downcase_atom(Char, LowerChar).


% =======================================================
% 2. TABELA DE FREQUÊNCIAS
% =======================================================

% Constrói a tabela de frequências e ordena do menor para o maior
construir_tabela_frequencias(ListaChars, TabelaOrdenada) :-
    msort(ListaChars, CharsAgrupados),      % Agrupa caracteres iguais
    empacotar(CharsAgrupados, Pacotes),     % Cria listas de repetidos: [[a,a], [b], [c,c,c]]
    maplist(pacote_para_folha, Pacotes, Tabela),
    sort(1, @=<, Tabela, TabelaOrdenada).   % Ordena pela frequência (argumento 1 da folha)

empacotar([], []).
empacotar([X|Xs], [[X|Zs]|Zss]) :- transferir(X, Xs, Zs, Ys), empacotar(Ys, Zss).

transferir(X, [X|Xs], [X|Zs], Ys) :- !, transferir(X, Xs, Zs, Ys).
transferir(_, Ys, [], Ys).

% Cria a estrutura folha(Freq, Char)
pacote_para_folha([Char|Rest], folha(Freq, Char)) :-
    length([Char|Rest], Freq).


% =======================================================
% 3. ÁRVORE DE HUFFMAN
% =======================================================

% Retorna o peso de um nó
no_peso(folha(Peso, _), Peso).
no_peso(no_interno(Peso, _, _), Peso).

% Insere um nó de forma ordenada na fila de prioridade
inserir_ordenado(No, [], [No]) :- !.
inserir_ordenado(No, [H|T], [No, H|T]) :-
    no_peso(No, PN), no_peso(H, PH), PN =< PH, !.
inserir_ordenado(No, [H|T], [H|TNovo]) :-
    inserir_ordenado(No, T, TNovo).

% Caso base: sobrou apenas a raiz
construir_arvore_huffman([Raiz], Raiz) :- !.

% Caso especial: arquivo com apenas 1 caractere único
construir_arvore_huffman([folha(Freq, Char)], no_interno(Freq, folha(Freq, Char), folha(0, nulo))) :- !.

% Repete unindo os dois menores nós até sobrar um (Huffman)
construir_arvore_huffman([Menor1, Menor2 | RestoFila], Raiz) :-
    no_peso(Menor1, P1), no_peso(Menor2, P2),
    PNovo is P1 + P2,
    NovoNo = no_interno(PNovo, Menor1, Menor2),
    inserir_ordenado(NovoNo, RestoFila, NovaFila),
    construir_arvore_huffman(NovaFila, Raiz).


% =======================================================
% 4. TABELA DE CÓDIGOS E CODIFICAÇÃO
% =======================================================

% Percorre a árvore acumulando os prefixos '0' (esq) e '1' (dir)
gerar_tabela_codigos(Arvore, Tabela) :-
    percorrer_arvore(Arvore, "", TabelaNaoAchata),
    flatten(TabelaNaoAchata, Tabela).

percorrer_arvore(folha(_, nulo), _, []) :- !. % Ignora sentinela nula
percorrer_arvore(folha(_, Char), Prefixo, [Char-Prefixo]).
percorrer_arvore(no_interno(_, Esq, Dir), Prefixo, [TabelaEsq, TabelaDir]) :-
    string_concat(Prefixo, "0", PrefixoEsq),
    string_concat(Prefixo, "1", PrefixoDir),
    percorrer_arvore(Esq, PrefixoEsq, TabelaEsq),
    percorrer_arvore(Dir, PrefixoDir, TabelaDir).

% Substitui cada caractere pelo seu código binário
codificar_texto([], _, "").
codificar_texto([Char|Resto], TabelaCodigos, TextoCodificado) :-
    ( member(Char-Codigo, TabelaCodigos) -> true ; Codigo = "" ),
    codificar_texto(Resto, TabelaCodigos, RestoCodificado),
    string_concat(Codigo, RestoCodificado, TextoCodificado).


% =======================================================
% 5. IMPRESSÕES E ESTATÍSTICAS
% =======================================================

imprimir_tabela_frequencias(Tabela) :-
    format('~n=== Tabela de Frequencias ===~n'),
    forall(member(folha(Freq, Char), Tabela),
           format('  \'~w\'  ->  ~w~n', [Char, Freq])).

imprimir_tabela_codigos(Tabela) :-
    format('~n=== Tabela de Codigos de Huffman ===~n'),
    keysort(Tabela, TabelaOrdenada), % Ordena alfabeticamente pela chave (Char)
    forall(member(Char-Codigo, TabelaOrdenada),
           format('  \'~w\'  ->  ~w~n', [Char, Codigo])).

imprimir_estatisticas(Original, Codificado) :-
    length(Original, QtdChars),
    BitsOrig is QtdChars * 8,
    string_length(Codificado, BitsCod),
    Taxa is 100.0 * (1.0 - (BitsCod / BitsOrig)),
    format('~n=== Estatisticas de Compressao ===~n'),
    format('  Caracteres no texto : ~w~n', [QtdChars]),
    format('  Tamanho original    : ~w bits~n', [BitsOrig]),
    format('  Tamanho codificado  : ~w bits~n', [BitsCod]),
    format('  Taxa de compressao  : ~2f%~n', [Taxa]).


% =======================================================
% 6. GRAVAÇÃO DE ARQUIVO E ORQUESTRAÇÃO
% =======================================================

gravar_arquivo(Caminho, TabelaCod, TextoCod) :-
    open(Caminho, write, Stream),
    format(Stream, '=== TABELA DE CODIGOS ===~n', []),
    keysort(TabelaCod, TabelaOrdenada),
    forall(member(Char-Codigo, TabelaOrdenada),
           format(Stream, '~w ~w~n', [Char, Codigo])),
    format(Stream, '=== TEXTO CODIFICADO ===~n', []),
    format(Stream, '~w~n', [TextoCod]),
    close(Stream).

% Predicado principal
codificar_arquivo(ArquivoEntrada, ArquivoSaida) :-
    format('~n[1/5] Lendo arquivo: ~w~n', [ArquivoEntrada]),
    ler_arquivo(ArquivoEntrada, Chars),
    
    ( Chars == [] -> 
        format('Erro: Arquivo vazio ou sem caracteres validos: ~w~n', [ArquivoEntrada]), fail
    ; true ),
    
    format('[2/5] Construindo tabela de frequencias...~n'),
    construir_tabela_frequencias(Chars, TabelaFreq),
    imprimir_tabela_frequencias(TabelaFreq),
    
    format('~n[3/5] Construindo arvore de Huffman...~n'),
    construir_arvore_huffman(TabelaFreq, Arvore),
    
    format('[4/5] Gerando tabela de codigos...~n'),
    gerar_tabela_codigos(Arvore, TabelaCod),
    imprimir_tabela_codigos(TabelaCod),
    
    format('~n[5/5] Codificando texto e gravando: ~w~n', [ArquivoSaida]),
    codificar_texto(Chars, TabelaCod, TextoCod),
    imprimir_estatisticas(Chars, TextoCod),
    
    gravar_arquivo(ArquivoSaida, TabelaCod, TextoCod),
    format('~nConcluido! Arquivo gerado: ~w~n~n', [ArquivoSaida]).